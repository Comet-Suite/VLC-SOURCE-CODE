// SPDX-License-Identifier: LGPL-2.1-or-later
/* ECM filter regression tests using real PAT/PMT parsing and a mock CAM. */
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#define MODULE_NAME test_ts_ecm
#undef VLC_DYNAMIC_PLUGIN
#include "../../libvlc/test.h"
#include "../../../lib/libvlc_internal.h"
#include <vlc_demux.h>
#include <vlc_plugin.h>
#include "../../../modules/demux/mpeg/ts_pid.h"
#include "../../../modules/demux/mpeg/ts_streams_private.h"
#include "../../../modules/demux/mpeg/ts.h"

const char vlc_module_name[] = MODULE_STRING;
static unsigned cam_opens;

static ssize_t CAMRead(stream_t *s, void *buf, size_t len)
{
    return vlc_stream_Read(s->s, buf, len);
}

static int CAMControl(stream_t *s, int query, va_list args)
{
    return vlc_stream_vaControl(s->s, query, args);
}

static int CAMOpen(vlc_object_t *obj)
{
    stream_t *s = (stream_t *)obj;
    s->pf_read = CAMRead;
    s->pf_control = CAMControl;
    cam_opens++;
    return VLC_SUCCESS;
}

vlc_module_begin()
    set_capability("stream_filter", 1000)
    add_shortcut("aribcam")
    set_callback(CAMOpen)
vlc_module_end()

VLC_EXPORT const vlc_plugin_cb vlc_static_modules[] = {
    VLC_SYMBOL(vlc_entry), NULL
};

struct input
{
    uint8_t data[188 * 128];
    size_t size, pos;
    uint8_t cc[8192];
    bool filtered[8192];
};

static ssize_t Read(stream_t *s, void *buf, size_t len)
{
    struct input *in = s->p_sys;
    len = __MIN(len, __MIN(in->size - in->pos, 188));
    if (buf)
        memcpy(buf, in->data + in->pos, len);
    in->pos += len;
    return len;
}

static int Control(stream_t *s, int query, va_list args)
{
    struct input *in = s->p_sys;
    switch (query)
    {
        case STREAM_CAN_SEEK:
        case STREAM_CAN_FASTSEEK:
        case STREAM_CAN_PAUSE:
        case STREAM_CAN_CONTROL_PACE:
            *va_arg(args, bool *) = false;
            return VLC_SUCCESS;
        case STREAM_GET_PTS_DELAY:
            *va_arg(args, vlc_tick_t *) = 0;
            return VLC_SUCCESS;
        case STREAM_SET_PRIVATE_ID_STATE:
        {
            unsigned pid = va_arg(args, int);
            assert(pid < ARRAY_SIZE(in->filtered));
            in->filtered[pid] = va_arg(args, int);
            return VLC_SUCCESS;
        }
        default:
            return VLC_EGENERIC;
    }
}

static void Destroy(stream_t *s) { (void)s; }

static es_out_id_t *Add(es_out_t *out, input_source_t *source,
                       const es_format_t *fmt)
{
    (void)source; (void)fmt;
    return (es_out_id_t *)out;
}

static void Del(es_out_t *out, es_out_id_t *id) { (void)out; (void)id; }

static int Send(es_out_t *out, es_out_id_t *id, block_t *block)
{
    (void)out; (void)id;
    block_Release(block);
    return VLC_SUCCESS;
}

static int OutControl(es_out_t *out, input_source_t *source,
                      int query, va_list args)
{
    (void)out; (void)source;
    if (query == ES_OUT_GET_ES_STATE)
    {
        (void)va_arg(args, es_out_id_t *);
        *va_arg(args, bool *) = true;
    }
    return VLC_SUCCESS;
}

static const struct es_out_callbacks out_cbs = {
    .add = Add, .del = Del, .send = Send, .control = OutControl,
};

/* Generate the MPEG-2 CRC, then encapsulate a small PSI section in one TS
 * packet. Padding also provides enough sync bytes for format detection. */
static void Section(struct input *in, unsigned pid, uint8_t *section, size_t len)
{
    assert(len + 4 <= 183);
    unsigned section_length = len + 4 - 3;
    section[1] = 0xb0 | (section_length >> 8);
    section[2] = section_length;
    uint32_t crc = 0xffffffff;
    for (size_t i = 0; i < len; ++i)
    {
        crc ^= (uint32_t)section[i] << 24;
        for (unsigned bit = 0; bit < 8; ++bit)
            crc = (crc << 1) ^ ((crc & 0x80000000) ? 0x04c11db7 : 0);
    }
    SetDWBE(section + len, crc);
    assert(in->size + 5 * 188 <= sizeof(in->data));
    uint8_t *packet = in->data + in->size;
    memset(packet, 0xff, 188);
    packet[0] = 0x47;
    packet[1] = 0x40 | (pid >> 8);
    packet[2] = pid;
    packet[3] = 0x10 | (in->cc[pid]++ & 0xf);
    packet[4] = 0;
    memcpy(packet + 5, section, len + 4);
    in->size += 188;
    for (unsigned i = 0; i < 4; ++i)
    {
        packet = in->data + in->size;
        memset(packet, 0xff, 188);
        packet[0] = 0x47;
        packet[1] = 0x1f;
        packet[2] = 0xff;
        packet[3] = 0x10;
        in->size += 188;
    }
}

static void PAT(struct input *in, unsigned version, bool first_program)
{
    uint8_t section[32] = {0x00, 0, 0, 0, 1, 0xc1 | (version << 1), 0, 0};
    size_t len = 8;
    if (first_program)
    {
        SetWBE(section + len, 1);
        SetWBE(section + len + 2, 0xe100);
        len += 4;
    }
    SetWBE(section + len, 2);
    SetWBE(section + len + 2, 0xe200);
    Section(in, 0, section, len + 4);
}

static void PMT(struct input *in, unsigned program, unsigned version,
                const uint8_t *program_ca, size_t program_len,
                const uint8_t *es_ca, size_t es_len)
{
    uint8_t section[183] = {0x02, 0, 0, 0, program,
                           0xc1 | (version << 1), 0, 0, 0xff, 0xff, 0xf0, program_len};
    size_t len = 12;
    if (program_len)
        memcpy(section + len, program_ca, program_len);
    len += program_len;
    section[len++] = 0x06; /* Unknown private ES, requiring no packetizer. */
    SetWBE(section + len, 0xe300 + program);
    len += 2;
    SetWBE(section + len, 0xf000 | es_len);
    len += 2;
    if (es_len)
        memcpy(section + len, es_ca, es_len);
    Section(in, program << 8, section, len + es_len);
}

static ts_pid_t *FindPID(demux_t *demux, unsigned pid)
{
    demux_sys_t *sys = demux->p_sys;
    for (int i = 0; i < sys->pids.i_all; ++i)
        if (sys->pids.pp_all[i]->i_pid == pid)
            return sys->pids.pp_all[i];
    return NULL;
}

static void UntilPMT(demux_t *demux, unsigned program, int version)
{
    for (unsigned i = 0; i < 128; ++i)
    {
        ts_pid_t *pid = FindPID(demux, program << 8);
        if (pid && pid->type == TYPE_PMT && pid->u.p_pmt->i_version == version)
            return;
        assert(demux_Demux(demux) == VLC_DEMUXER_SUCCESS);
    }
    assert(!"PMT not received");
}

static demux_t *Open(libvlc_instance_t *vlc, struct input *in, es_out_t *out)
{
    stream_t *s = vlc_stream_CommonNew(VLC_OBJECT(vlc->p_libvlc_int), Destroy);
    assert(s);
    s->p_sys = in;
    s->pf_read = Read;
    s->pf_control = Control;
    demux_t *demux = demux_New(VLC_OBJECT(s), "ts", "isdb-t://test", s, out);
    assert(demux);
    demux_sys_t *sys = demux->p_sys;
    sys->i_ts_read = 1;
    return demux;
}

static void Select(demux_t *demux, size_t count, const int *programs)
{
    assert(demux_Control(demux, DEMUX_SET_GROUP_LIST, count, programs) == VLC_SUCCESS);
}

static void TestFilters(libvlc_instance_t *vlc)
{
    struct input in = {0};
    es_out_t out = {.cbs = &out_cbs};
    const uint8_t ca1[] = {0x09, 4, 0, 5, 0xe9, 1};
    const uint8_t es_ca[] = {0x09, 4, 0, 5, 0xe9, 1, /* Duplicate ECM. */
                             0x09, 4, 0, 5, 0xe9, 2};
    const uint8_t ca2[] = {0x09, 4, 0, 5, 0xe9, 1, /* Shared ECM. */
                            0x09, 4, 0, 5, 0xe9, 3,
                            0x09, 3, 0, 5, 0xe9,    /* Truncated descriptor. */
                            0x09, 4, 0, 6, 0xe9, 5, /* Unsupported CA system. */
                            0x09, 4, 0, 5, 0xff, 0xff}; /* Null PID. */
    const uint8_t changed[] = {0x09, 4, 0, 5, 0xe9, 4};
    PAT(&in, 0, true);
    PMT(&in, 1, 0, ca1, sizeof(ca1), es_ca, sizeof(es_ca));
    PMT(&in, 2, 0, ca2, sizeof(ca2), NULL, 0);
    PMT(&in, 1, 1, ca1, sizeof(ca1), es_ca, sizeof(es_ca));
    PMT(&in, 1, 2, changed, sizeof(changed), NULL, 0);
    PMT(&in, 2, 1, NULL, 0, NULL, 0);
    PAT(&in, 1, false);

    cam_opens = 0;
    demux_t *demux = Open(vlc, &in, &out);
    UntilPMT(demux, 2, 0);
    assert(cam_opens == 1);
    assert(in.filtered[0x901] && in.filtered[0x902]);
    assert(!in.filtered[0x903] && !in.filtered[0x905]);
    assert(FindPID(demux, 0x901)->i_refcount == 2);

    const int both[] = {1, 2}, first[] = {1}, second[] = {2};
    Select(demux, 2, both);
    assert(in.filtered[0x901] && in.filtered[0x902] && in.filtered[0x903]);
    Select(demux, 1, second);
    assert(in.filtered[0x901] && !in.filtered[0x902] && in.filtered[0x903]);
    UntilPMT(demux, 1, 1);
    assert(FindPID(demux, 0x901)->i_refcount == 2);
    assert(in.filtered[0x901] && !in.filtered[0x902]);
    UntilPMT(demux, 1, 2);
    assert(in.filtered[0x901] && !in.filtered[0x904]);
    assert(FindPID(demux, 0x901)->i_refcount == 1);
    assert(FindPID(demux, 0x902)->type == TYPE_FREE);
    Select(demux, 1, first);
    assert(in.filtered[0x904] && !in.filtered[0x901] && !in.filtered[0x903]);
    UntilPMT(demux, 2, 1);
    assert(FindPID(demux, 0x901)->type == TYPE_FREE);
    assert(FindPID(demux, 0x903)->type == TYPE_FREE);
    while (demux_Demux(demux) == VLC_DEMUXER_SUCCESS) {}
    assert(!in.filtered[0x904]);
    assert(FindPID(demux, 0x904)->type == TYPE_FREE);
    demux_Delete(demux);
}

static void TestProgramCA(libvlc_instance_t *vlc)
{
    struct input in = {0};
    es_out_t out = {.cbs = &out_cbs};
    const uint8_t ca[] = {0x09, 4, 0, 5, 0xe9, 1};
    PAT(&in, 0, true);
    PMT(&in, 1, 0, ca, sizeof(ca), NULL, 0);
    cam_opens = 0;
    demux_t *demux = Open(vlc, &in, &out);
    UntilPMT(demux, 1, 0);
    assert(cam_opens == 1);
    assert(in.filtered[0x901]);
    demux_Delete(demux);
    assert(!in.filtered[0x901]);
}

int main(void)
{
    test_init();
    const char *args[] = {"--quiet", "--ts-standard=arib"};
    libvlc_instance_t *vlc = libvlc_new(ARRAY_SIZE(args), args);
    assert(vlc);
    TestFilters(vlc);
    TestProgramCA(vlc);
    libvlc_release(vlc);
    return 0;
}
