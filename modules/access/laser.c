/*****************************************************************************
 * laser.c: disc classification for USB optical drives on Android
 *****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * Authors: Pierre Bogdanovscky
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************
 * Two submodules sharing one access_sys_t:
 *
 *  - classification, shortcut "laser-dir", location "<fd>": pf_readdir lists
 *    the MRL(s) that will play the disc, laser/<demux>://<fd> for media read
 *    as 2048-byte blocks, <access>://laser/<fd> for raw CD sectors. The fd is
 *    stale once the browse ends; the caller substitutes a fresh one.
 *
 *  - playback, shortcut "laser", location "<fd>": a byte stream over the same
 *    transport, read by the unmodified dvdnav, dvdread and bluray demuxers.
 *    CSS authentication is left to libdvdcss.
 *****************************************************************************/

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <inttypes.h>
#include <assert.h>

#include <stdatomic.h>

#include <vlc_common.h>
#include <vlc_plugin.h>
#include <vlc_access.h>
#include <vlc_input_item.h>
#include <vlc_interrupt.h>
#include <vlc_iso_lang.h>

#include <laser.h>
#include <laser_disc.h>

/* Block size READ CAPACITY must report. */
#define LASER_SECTOR_SIZE 2048

/* Read-ahead window, in sectors. */
#define LASER_MAX_READ_SECTORS 128

/* The window read after a jump, in sectors: one liblaser command, 64 KiB.
 * What a jump reads - an IFO's tables, a menu's first VOBU - is mostly
 * smaller, and a full window costs 256 KiB of transfer; reads going on from
 * there get full windows again. */
#define LASER_JUMP_READ_SECTORS 32

typedef struct
{
    int          token;
    uint64_t     i_size;
    uint64_t     i_pos;
    vlc_thread_t readahead_thread;
    bool         b_readahead_started;
    atomic_bool  b_media_gone;
    bool         b_media_gone_reported; /* See StreamMediaGoneRead(). */
    /* The input is stopping, or the stream closing: the reads in progress,
     * on either thread, give up. See StreamAbort(). */
    atomic_bool  b_abort;
    vlc_mutex_t  lock;
    vlc_cond_t   wait_worker;   /* worker waits here for a request      */
    vlc_cond_t   wait_done;     /* consumer waits here for a completion */
    bool         b_quit;
    bool         b_ahead_wanted;
    bool         b_ahead_busy;
    bool         b_ahead_ready;
    uint32_t     i_ahead_lba;
    int          i_ahead_blocks;
    int          i_ahead_status;
    uint8_t     *p_ahead;
    vlc_mutex_t  io_lock;
    uint32_t     i_cache_lba;
    uint32_t     i_cache_blocks; /* 0 = empty */
    uint8_t     *p_cache;
} access_sys_t;

/* ============================================================================
 * Module boilerplate
 * ============================================================================ */

static int  OpenDir   (vlc_object_t *);
static int  OpenStream(vlc_object_t *);
static void Close     (vlc_object_t *);

/* Capability 0: both are reached only when an MRL names them, laser-dir://<fd>
 * or laser/<demuxer>://<fd>. The playback MRL reaches the access as
 * laser://<fd>, so a listing needs a shortcut of its own - and OpenDir() must
 * check it, since VLC gives the module name "laser" to both as a shortcut. */
vlc_module_begin ()
set_shortname("laser")
set_description(N_("Android USB optical drive disc classification"))
set_capability("access", 0)
set_subcategory(SUBCAT_INPUT_ACCESS)
add_shortcut( "laser-dir" )
set_callbacks(OpenDir, Close)

add_submodule()
    set_description(N_("Android USB optical drive disc playback"))
    set_subcategory(SUBCAT_INPUT_ACCESS)
    set_capability("access", 0)
    add_shortcut( "laser" )
    set_callbacks(OpenStream, Close)
vlc_module_end ()

/* ============================================================================
 * pf_readdir
 * ============================================================================ */

struct laser_dir_entry
{
    char *psz_uri;
    char *psz_name;
};

/* Drops the row on failure rather than failing the whole browse. */
static void DirAddEntry(struct laser_dir_entry *entries, int *pi_count,
                        int i_capacity, const char *psz_uri_fmt, int token,
                        const char *psz_name)
{
    if (*pi_count >= i_capacity)
        return;

    struct laser_dir_entry *e = &entries[*pi_count];

    if (asprintf(&e->psz_uri, psz_uri_fmt, token) == -1)
        return;                 /* e->psz_uri is indeterminate: do not free */

    e->psz_name = strdup(psz_name);
    if (e->psz_name == NULL)
    {
        free(e->psz_uri);
        return;
    }

    (*pi_count)++;
}

/* liblaser's abort check while classifying: the preparser gave up - its
 * timeout, or the item cancelled. Called on DirRead()'s thread, whose
 * interrupt context that is. */
static int DirAborted(void *opaque)
{
    (void)opaque;
    return vlc_killed();
}

/* The disc's volume label, else [psz_default]. */
static const char *DiscLabel(const laser_disc_t *disc, const char *psz_default)
{
    return disc->volume_id[0] != '\0' ? disc->volume_id : psz_default;
}

static int DirRead(stream_t *access, input_item_node_t *p_node)
{
    access_sys_t *sys = access->p_sys;
    int token = sys->token;
    struct vlc_readdir_helper rdh;
    vlc_readdir_helper_init(&rdh, access, p_node);

    /* At most two rows per disc. */
    struct laser_dir_entry entries[2];
    const int i_capacity = ARRAY_SIZE(entries);
    int i_entries = 0;

    msg_Dbg(access, "classifying token=%d", token);

    /* A Blu-ray's title in the menu language, as bluray.c reads it. Both
     * ISO 639-2 forms, since disc authors use either. */
    const char *langs[3] = { NULL, NULL, NULL };
    char *psz_lang = var_InheritString(access, "menu-language");
    if (psz_lang != NULL)
    {
        char *psz_comma = strchr(psz_lang, ',');
        if (psz_comma != NULL)
            *psz_comma = '\0';

        const iso639_lang_t *pl = vlc_find_iso639(psz_lang, true);
        if (pl != NULL)
        {
            int i_langs = 0;
            if (pl->psz_iso639_2T[0] != '\0')
                langs[i_langs++] = pl->psz_iso639_2T;
            if (pl->psz_iso639_2B[0] != '\0' &&
                strcmp(pl->psz_iso639_2B, pl->psz_iso639_2T) != 0)
                langs[i_langs++] = pl->psz_iso639_2B;
        }
        free(psz_lang);
    }

    /* A classification given up stops at liblaser's next checkpoint, rather
     * than running its retries and readiness waits to their end while the
     * drive stays claimed. Every read below happens on this thread. */
    laser_set_abort_cb(DirAborted, NULL);

    laser_disc_t disc;
    laser_disc_identify_lang(token, langs, &disc);

    laser_set_abort_cb(NULL, NULL);

    /* Stopped: what was read may be partial - a disc taken for unknown. No
     * row, rather than a wrong one. */
    const bool b_stopped = vlc_killed();

    switch (disc.kind)
    {
        case LASER_DISC_CD_AUDIO:
            /* Red Book audio has no label. */
            DirAddEntry(entries, &i_entries, i_capacity,
                        "cdda://laser/%d", token, "CD Audio");
            break;

        case LASER_DISC_DVD_VIDEO:
            /* With menus, then without; the Kotlin side labels the second. */
            DirAddEntry(entries, &i_entries, i_capacity, "laser/dvd://%d",
                        token, DiscLabel(&disc, "DVD-Video"));
            DirAddEntry(entries, &i_entries, i_capacity, "laser/dvdsimple://%d",
                        token, DiscLabel(&disc, "DVD-Video"));
            break;

        case LASER_DISC_DVD_AUDIO:
            DirAddEntry(entries, &i_entries, i_capacity, "laser/dvda://%d",
                        token, DiscLabel(&disc, "DVD-Audio"));
            break;

        case LASER_DISC_DVD_UNIVERSAL:
            /* Audio zone first; the Kotlin side tells the rows apart by
             * their icon. */
            DirAddEntry(entries, &i_entries, i_capacity, "laser/dvda://%d",
                        token, DiscLabel(&disc, "DVD"));
            DirAddEntry(entries, &i_entries, i_capacity, "laser/dvd://%d",
                        token, DiscLabel(&disc, "DVD"));
            break;

        case LASER_DISC_BD_VIDEO:
            /* libbluray falls back to the first playlist without menus. */
            DirAddEntry(entries, &i_entries, i_capacity, "laser/bluray://%d",
                        token, disc.title[0] != '\0'
                               ? disc.title : DiscLabel(&disc, "Blu-ray Disc"));
            break;

        case LASER_DISC_VCD:
            DirAddEntry(entries, &i_entries, i_capacity, "vcd://laser/%d",
                        token, DiscLabel(&disc, "Video CD"));
            break;

        case LASER_DISC_SVCD:
            DirAddEntry(entries, &i_entries, i_capacity, "svcd://laser/%d",
                        token, DiscLabel(&disc, "Super Video CD"));
            break;

        /* Data disc, empty drive or read failure: no row. */
        case LASER_DISC_UNKNOWN:
            break;
    }

    int i_ret = VLC_SUCCESS;
    if (b_stopped)
    {
        msg_Dbg(access, "classification of token=%d stopped", token);
        i_ret = VLC_EGENERIC;
    }
    else if (i_entries == 0)
    {
        msg_Dbg(access, "no CD/VCD/DVD/BD recognized on token=%d "
                "(data disc, empty drive, or read failure)", token);
    }

    for (int i = 0; i < i_entries && i_ret == VLC_SUCCESS; i++)
    {
        msg_Dbg(access, "classified as '%s' (%s)",
                entries[i].psz_name, entries[i].psz_uri);
        i_ret = vlc_readdir_helper_additem(&rdh, entries[i].psz_uri, NULL,
                                           entries[i].psz_name,
                                           ITEM_TYPE_DISC, ITEM_LOCAL, NULL);
    }

    for (int i = 0; i < i_entries; i++)
    {
        free(entries[i].psz_uri);
        free(entries[i].psz_name);
    }

    vlc_readdir_helper_finish(&rdh, i_ret == VLC_SUCCESS);
    return i_ret;
}

/* ============================================================================
 * Open / Close
 * ============================================================================ */

/* Reached through laser-dir://<fd>, and through laser://<fd>, which is
 * playback's: the location is the fd, the access name says which. */
static int OpenDir(vlc_object_t *obj)
{
    stream_t *access = (stream_t *)obj;

    if (access->psz_name == NULL || strcmp(access->psz_name, "laser-dir") != 0)
        return VLC_EGENERIC;

    int fd;
    if (!laser_parse_token(access->psz_location, &fd))
        return VLC_EGENERIC;

    msg_Dbg(access, "OpenDir() accepted '%s://%s' (fd=%d)",
            access->psz_name, access->psz_location, fd);

    access_sys_t *sys = vlc_obj_calloc(obj, 1, sizeof(*sys));
    if (unlikely(sys == NULL))
        return VLC_ENOMEM;

    sys->token = fd;
    access->p_sys = sys;

    /* The first claim also sets the drive up and waits for it to spin up. */
    if (laser_acquire(fd) != LASER_OK)
    {
        msg_Warn(access, "cannot acquire token=%d", fd);
        return VLC_EGENERIC;
    }

    access->pf_readdir = DirRead;
    access->pf_control = access_vaDirectoryControlHelper;

    return VLC_SUCCESS;
}

/* ============================================================================
 * Playback: byte-stream access over the same SCSI transport
 * ============================================================================ */

/* A changed medium is treated like an ejection. liblaser forgets what it
 * knew of the old one's sectors. */
static void StreamForgetMedium(stream_t *access)
{
    access_sys_t *sys = access->p_sys;

    msg_Warn(access, "the medium may have changed - giving up on this "
             "medium");

    /* Latched, or the caller would keep reading. */
    atomic_store_explicit(&sys->b_media_gone, true, memory_order_relaxed);
}

/* -1 first, so the application sees an error rather than a title that ended,
 * then 0 for ever, so a caller that retries -1 does not spin on it. */
static ssize_t StreamMediaGoneRead(stream_t *access)
{
    access_sys_t *sys = access->p_sys;

    if (sys->b_media_gone_reported)
        return 0;

    sys->b_media_gone_reported = true;
    msg_Err(access, "the disc is no longer in the drive - "
            "stopping playback");
    return -1;
}

/* Medium gone or drive unplugged: latched by StreamForgetMedium(). */
static bool StreamIsTerminal(int i_status)
{
    return i_status == (int)LASER_ERR_MEDIA_GONE ||
           i_status == (int)LASER_ERR_NO_DEVICE;
}

/* Sectors the drive could not read, read as zeros.
 *
 * A read failing on the disc - liblaser's LASER_ERR_IO, its retries spent -
 * is not passed on: VLC's cache_read filter retries a failed read for as long
 * as the input runs. Some protections put unreadable sectors on purpose where
 * no title plays, for a program reading the disc from its start to stop on;
 * a scratch in the film gives a short glitch rather than a halt. liblaser
 * records them and fails at once a read starting in them, for every consumer
 * of the drive until the disc changes, and stops a read reaching them short:
 * this fills those it knows of, from [i_lba], at most [i_want] - one at
 * least, should it know of none. Returns their count. */
static int StreamUnreadable(stream_t *access, uint32_t i_lba, int i_want,
                            uint8_t *p_dst)
{
    access_sys_t *sys = access->p_sys;
    int i_count = laser_unreadable_blocks(sys->token, i_lba, i_want);
    if (i_count <= 0)
        i_count = 1;

    msg_Dbg(access, "LBA %u x %d unreadable - read as zeros", i_lba, i_count);
    memset(p_dst, 0, (size_t)i_count * LASER_SECTOR_SIZE);
    return i_count;
}

/* liblaser stops a read short of a refused sector, and of an unreadable one,
 * and reads the readable sectors before a refused one. A read starting on a
 * refused sector fails; once liblaser has seen it refused often enough, it
 * reads as end of stream, at that position only. A read failing on the disc
 * reads as zeros: see StreamUnreadable().
 *
 * Returns the sector count, 0 at end of medium, or a negative laser status. */
static int StreamReadSectors(stream_t *access, uint32_t i_lba, int i_want,
                             uint8_t *p_dst)
{
    access_sys_t *sys = access->p_sys;

    int i_read = laser_read_blocks(sys->token, i_lba, i_want, p_dst);

    if (StreamIsTerminal(i_read))
    {
        StreamForgetMedium(access);
        return i_read;
    }
    if (i_read == (int)LASER_ERR_IO)
        return StreamUnreadable(access, i_lba, i_want, p_dst);
    if (laser_status_is_positional(i_read) &&
        laser_refused_for_good(sys->token, i_lba))
        return 0;   /* refused for good: end of stream, here */

    return i_read;
}

/* Clamped to the medium: reading past it costs a full retry budget. */
static int StreamWindowSectors(access_sys_t *sys, uint32_t i_lba)
{
    int i_want = LASER_MAX_READ_SECTORS;

    if (sys->i_size != 0)
    {
        uint64_t i_total = sys->i_size / LASER_SECTOR_SIZE;
        if ((uint64_t)i_lba >= i_total)
            return 0;
        uint64_t i_left = i_total - i_lba;
        if ((uint64_t)i_want > i_left)
            i_want = (int)i_left;
    }

    return i_want;
}

/* liblaser's abort check, on whichever thread reads. */
static int StreamAborted(void *opaque)
{
    access_sys_t *sys = opaque;
    return atomic_load(&sys->b_abort);
}

/* Gives up the reads in progress. Called by VLC's interrupt, from the thread
 * stopping the input, while StreamRead() waits: a drive spinning up holds a
 * read for tens of seconds, and the input could not stop before it ends. And
 * by Close(), for the read-ahead's. */
static void StreamAbort(void *opaque)
{
    access_sys_t *sys = opaque;

    atomic_store(&sys->b_abort, true);
    vlc_mutex_lock(&sys->lock);
    vlc_cond_signal(&sys->wait_done);
    vlc_mutex_unlock(&sys->lock);
}

/* The only access to the transport, shared by both threads. */
static int StreamReadLocked(stream_t *access, uint32_t i_lba, int i_want,
                            uint8_t *p_dst)
{
    access_sys_t *sys = access->p_sys;

    if (atomic_load(&sys->b_abort))
        return (int)LASER_ERR_CANCELLED;

    vlc_mutex_lock(&sys->io_lock);
    laser_set_abort_cb(StreamAborted, sys);
    int i_read = StreamReadSectors(access, i_lba, i_want, p_dst);
    laser_set_abort_cb(NULL, NULL);
    vlc_mutex_unlock(&sys->io_lock);

    return i_read;
}

/* Caller holds sys->lock and has established that no fetch is in flight. */
static void StreamRequestAhead(access_sys_t *sys, uint32_t i_lba)
{
    if (StreamWindowSectors(sys, i_lba) <= 0)
        return;                 /* past the end - nothing to fetch */

    sys->i_ahead_lba    = i_lba;
    sys->b_ahead_wanted = true;
    sys->b_ahead_ready  = false;
    vlc_cond_signal(&sys->wait_worker);
}

static void *StreamReadaheadThread(void *p_data)
{
    stream_t     *access = p_data;
    access_sys_t *sys    = access->p_sys;

    vlc_mutex_lock(&sys->lock);
    for (;;)
    {
        while (!sys->b_quit && !sys->b_ahead_wanted)
            vlc_cond_wait(&sys->wait_worker, &sys->lock);
        if (sys->b_quit)
            break;

        uint32_t i_lba = sys->i_ahead_lba;
        sys->b_ahead_wanted = false;
        sys->b_ahead_busy   = true;

        /* Not held across the transfer. */
        vlc_mutex_unlock(&sys->lock);

        int i_want = atomic_load_explicit(&sys->b_media_gone,
                                          memory_order_relaxed)
                   ? 0 : StreamWindowSectors(sys, i_lba);
        int i_read = i_want > 0
                   ? StreamReadLocked(access, i_lba, i_want, sys->p_ahead)
                   : 0;

        vlc_mutex_lock(&sys->lock);
        sys->i_ahead_blocks = i_read > 0 ? i_read : 0;
        sys->i_ahead_status = i_read;
        sys->b_ahead_busy   = false;
        sys->b_ahead_ready  = true;
        vlc_cond_signal(&sys->wait_done);
    }
    vlc_mutex_unlock(&sys->lock);

    return NULL;
}

/* Returns the sector count, 0 at end of medium, or -1, logging why. A
 * failure is never the disc's: StreamReadSectors() reads a sector the drive
 * cannot read as zeros. It is the input stopping, a refusal, the CSS session
 * gone, or the disc or the drive gone. */
static int StreamClassifyRead(stream_t *access, int i_read,
                              uint32_t i_lba, int i_want,
                              const char *psz_what)
{
    if (i_read == (int)LASER_ERR_CANCELLED)
    {
        msg_Dbg(access, "%s read of %d sectors at LBA %u abandoned: stopping",
                psz_what, i_want, i_lba);
        return -1;
    }

    if (laser_status_is_positional(i_read) || i_read == (int)LASER_ERR_NO_KEY)
    {
        msg_Dbg(access, "%s read of %d sectors at LBA %u refused (%d)",
                psz_what, i_want, i_lba, i_read);
        return -1;
    }

    if (i_read < 0)
    {
        msg_Warn(access, "%s read of %d sectors at LBA %u failed (%d)",
                 psz_what, i_want, i_lba, i_read);
        return -1;
    }

    return i_read; /* 0: end of medium */
}

/* Leaves a fetch of the following window in flight, when the reads go on
 * sequentially. Returns the sector count now valid in the cache, 0 at end of
 * medium, or -1. */
static int StreamRefillCache(stream_t *access, uint32_t i_lba)
{
    access_sys_t *sys = access->p_sys;
    int i_read;

    /* Reading on from the end of the window: playback, a file read through.
     * Otherwise a jump - navigation, an IFO, a title set after another. */
    const bool b_sequential = sys->i_cache_blocks != 0 &&
                              i_lba == sys->i_cache_lba + sys->i_cache_blocks;

    sys->i_cache_blocks = 0;    /* invalid until refilled */

    vlc_mutex_lock(&sys->lock);

    /* A transfer in flight cannot be recalled, and writes into p_ahead. An
     * abort makes it end soon, but it is not waited for: nothing is taken
     * from p_ahead after one. */
    while (sys->b_ahead_busy && !atomic_load(&sys->b_abort))
        vlc_cond_wait(&sys->wait_done, &sys->lock);
    if (atomic_load(&sys->b_abort))
    {
        vlc_mutex_unlock(&sys->lock);
        return -1;
    }

    if (sys->b_ahead_ready && sys->i_ahead_lba == i_lba)
    {
        assert(!sys->b_ahead_busy);

        uint8_t *p_tmp = sys->p_cache;
        sys->p_cache   = sys->p_ahead;
        sys->p_ahead   = p_tmp;

        i_read              = sys->i_ahead_status;
        sys->i_cache_lba    = i_lba;
        sys->i_cache_blocks = sys->i_ahead_blocks;
        sys->b_ahead_ready  = false;

        if (i_read > 0)
            StreamRequestAhead(sys, i_lba + (uint32_t)i_read);
        vlc_mutex_unlock(&sys->lock);

        if (i_read < 0)
            return -1;
        return i_read;
    }

    /* Miss: first read, or a seek away from the prefetched run. A fetch
     * asked for and not started yet is dropped: it would delay this read
     * and the next ones, for a window a jump does not need. */
    sys->b_ahead_ready  = false;
    sys->b_ahead_wanted = false;
    vlc_mutex_unlock(&sys->lock);

    int i_want = StreamWindowSectors(sys, i_lba);
    if (i_want <= 0)
        return 0;
    if (!b_sequential && i_want > LASER_JUMP_READ_SECTORS)
        i_want = LASER_JUMP_READ_SECTORS;

    i_read = StreamClassifyRead(access,
                                StreamReadLocked(access, i_lba, i_want,
                                                 sys->p_cache),
                                i_lba, i_want, "window");
    if (i_read <= 0)
        return i_read;

    sys->i_cache_lba    = i_lba;
    sys->i_cache_blocks = i_read;

    /* Prefetching the next window only once the reads go on sequentially:
     * after a jump, the next read is most often another jump - scattered
     * IFO tables, a menu - and waits for the fetch it does not use, a USB
     * transfer being impossible to recall. Playback asks for the following
     * window synchronously once, then reads ahead. */
    if (b_sequential)
    {
        vlc_mutex_lock(&sys->lock);
        StreamRequestAhead(sys, i_lba + (uint32_t)i_read);
        vlc_mutex_unlock(&sys->lock);
    }

    return i_read;
}

static ssize_t StreamReadUninterruptible(stream_t *access, void *p_buffer,
                                         size_t i_len)
{
    access_sys_t *sys = access->p_sys;

    if (i_len == 0)
        return 0;

    if (atomic_load_explicit(&sys->b_media_gone, memory_order_relaxed))
        return StreamMediaGoneRead(access);

    /* End of medium is a clean EOF, not an error. */
    if (sys->i_size != 0 && sys->i_pos >= sys->i_size)
        return 0;

    if (sys->i_size != 0 && sys->i_pos + i_len > sys->i_size)
        i_len = (size_t)(sys->i_size - sys->i_pos);

    uint32_t i_lba    = (uint32_t)(sys->i_pos / LASER_SECTOR_SIZE);
    size_t   i_offset = (size_t)(sys->i_pos % LASER_SECTOR_SIZE);

    /* A sector refused for good reads as end of stream, at that position
     * only, without a command: see StreamReadSectors(). */
    if (laser_refused_for_good(sys->token, i_lba))
        return 0;

    /* Large aligned reads go straight to the caller's buffer. */
    if (i_offset == 0 &&
        i_len >= (size_t)LASER_MAX_READ_SECTORS * LASER_SECTOR_SIZE)
    {
        int i_blocks = (int)(i_len / LASER_SECTOR_SIZE);

        int i_read = StreamClassifyRead(access,
                                        StreamReadLocked(access, i_lba,
                                                         i_blocks, p_buffer),
                                        i_lba, i_blocks, "direct");
        if (i_read <= 0)
            return i_read;

        sys->i_pos += (uint64_t)i_read * LASER_SECTOR_SIZE;
        return (ssize_t)i_read * LASER_SECTOR_SIZE;
    }

    if (sys->i_cache_blocks == 0 ||
        i_lba < sys->i_cache_lba ||
        i_lba >= sys->i_cache_lba + sys->i_cache_blocks)
    {
        int i_read = StreamRefillCache(access, i_lba);
        if (i_read < 0)
            return -1;
        if (i_read == 0)
            return 0;
    }

    const uint32_t i_cached_lba    = sys->i_cache_lba;
    const uint32_t i_cached_blocks = sys->i_cache_blocks;

    /* A short read is allowed by stream_t. */
    size_t i_cache_offset = (size_t)(i_lba - i_cached_lba)
                          * LASER_SECTOR_SIZE + i_offset;
    size_t i_cache_valid  = (size_t)i_cached_blocks * LASER_SECTOR_SIZE;

    /* Would otherwise wrap and overrun the cache. */
    if (i_cache_offset >= i_cache_valid)
        return 0;

    size_t i_avail = i_cache_valid - i_cache_offset;

    if (i_len > i_avail)
        i_len = i_avail;

    memcpy(p_buffer, sys->p_cache + i_cache_offset, i_len);
    sys->i_pos += i_len;
    return (ssize_t)i_len;
}

/* While it reads, the input stopping aborts the read. */
static ssize_t StreamRead(stream_t *access, void *p_buffer, size_t i_len)
{
    access_sys_t *sys = access->p_sys;

    if (atomic_load(&sys->b_abort))
        return -1;

    vlc_interrupt_register(StreamAbort, sys);
    ssize_t i_ret = StreamReadUninterruptible(access, p_buffer, i_len);
    vlc_interrupt_unregister();

    if (atomic_load(&sys->b_abort))
        return -1;
    return i_ret;
}

/* The cache survives seeks: navigation often stays within one window. */
static int StreamSeek(stream_t *access, uint64_t i_pos)
{
    access_sys_t *sys = access->p_sys;
    sys->i_pos = i_pos;
    return VLC_SUCCESS;
}

static int StreamControl(stream_t *access, int i_query, va_list args)
{
    access_sys_t *sys = access->p_sys;

    switch (i_query)
    {
        case STREAM_CAN_SEEK:
        case STREAM_CAN_FASTSEEK:
        case STREAM_CAN_PAUSE:
        case STREAM_CAN_CONTROL_PACE:
            *va_arg(args, bool *) = true;
            break;

        case STREAM_GET_SIZE:
            if (sys->i_size == 0)
                return VLC_EGENERIC; /* unknown - READ CAPACITY declined */
            *va_arg(args, uint64_t *) = sys->i_size;
            break;

        case STREAM_GET_PTS_DELAY:
            *va_arg(args, vlc_tick_t *) =
                    VLC_TICK_FROM_MS(var_InheritInteger(access, "disc-caching"));
            break;

        case STREAM_SET_PAUSE_STATE:
            /* Nothing to suspend between reads. */
            break;

        default:
            return VLC_EGENERIC;
    }

    return VLC_SUCCESS;
}

/* Only reached through laser/<demux>://<fd>: the location is the fd. */
static int OpenStream(vlc_object_t *obj)
{
    stream_t *access = (stream_t *)obj;

    int fd;
    if (!laser_parse_token(access->psz_location, &fd))
        return VLC_EGENERIC;

    msg_Dbg(access, "OpenStream() accepted '%s://%s' (fd=%d)",
            access->psz_name, access->psz_location, fd);

    access_sys_t *sys = vlc_obj_calloc(obj, 1, sizeof(*sys));
    if (unlikely(sys == NULL))
        return VLC_ENOMEM;

    sys->token = fd;

    const size_t i_window = (size_t)LASER_MAX_READ_SECTORS
                          * LASER_SECTOR_SIZE;
    sys->p_cache = vlc_obj_malloc(obj, i_window);
    sys->p_ahead = vlc_obj_malloc(obj, i_window);
    if (unlikely(sys->p_cache == NULL || sys->p_ahead == NULL))
        return VLC_ENOMEM;

    vlc_mutex_init(&sys->lock);
    vlc_mutex_init(&sys->io_lock);
    vlc_cond_init(&sys->wait_worker);
    vlc_cond_init(&sys->wait_done);

    access->p_sys = sys;

    /* Held for the stream's lifetime; libdvdcss may hold the same token. */
    if (laser_acquire(sys->token) != LASER_OK)
    {
        msg_Err(access, "cannot acquire token=%d", sys->token);
        return VLC_EGENERIC;
    }

    /* Left 0, unknown, if the drive will not say: liblaser logs why. */
    uint32_t i_blocks;
    if (laser_capacity(fd, &i_blocks) == LASER_OK)
    {
        sys->i_size = (uint64_t)i_blocks * LASER_SECTOR_SIZE;
        msg_Dbg(access, "medium size %" PRIu64 " bytes (%" PRIu32
                " sectors)", sys->i_size, i_blocks);
    }

    if (vlc_clone(&sys->readahead_thread, StreamReadaheadThread, access) == 0)
        sys->b_readahead_started = true;
    else
        msg_Warn(access, "no read-ahead thread; reads will be "
                 "synchronous and playback of high-bitrate discs may stall");

    access->pf_read    = StreamRead;
    access->pf_block   = NULL;
    access->pf_seek    = StreamSeek;
    access->pf_readdir = NULL;
    access->pf_control = StreamControl;

    return VLC_SUCCESS;
}

static void Close(vlc_object_t *obj)
{
    /* Shared by both submodules. The fd belongs to the caller. */
    stream_t *access = (stream_t *)obj;
    access_sys_t *sys = access->p_sys;

    /* Stop the worker before releasing the token it reads from - and its
     * read first, which a drive spinning up would hold for tens of seconds. */
    if (sys->b_readahead_started)
    {
        StreamAbort(sys);
        vlc_mutex_lock(&sys->lock);
        sys->b_quit = true;
        vlc_cond_signal(&sys->wait_worker);
        vlc_mutex_unlock(&sys->lock);
        vlc_join(sys->readahead_thread, NULL);
        sys->b_readahead_started = false;
    }

    /* Torn down only once no other consumer holds a claim. */
    laser_release(sys->token);
}
