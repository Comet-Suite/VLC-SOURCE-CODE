// SPDX-License-Identifier: LGPL-2.1-or-later
/*****************************************************************************
 * text_renderer.c: test when the text renderer is loaded
 *****************************************************************************
 * Copyright (C) 2026 VideoLAN and authors
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published
 * by the Free Software Foundation; either version 2.1 of the License, or
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
 *****************************************************************************/

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "test.h"
#include <string.h>
#include <vlc_common.h>
#include <vlc_threads.h>
#include <vlc_tick.h>

#define WIDTH 64
#define HEIGHT 64
#define FRAMES 10

struct ctx
{
    vlc_mutex_t lock;
    vlc_cond_t cond;
    unsigned text_loads;
    unsigned frames;
};

/* vmem may align the plane lines: leave room for them */
static uint8_t pixels[3][WIDTH * HEIGHT * 2];

static void on_log(void *data, int level, const libvlc_log_t *log,
                   const char *fmt, va_list ap)
{
    struct ctx *ctx = data;
    char msg[256];
    (void) level; (void) log;

    vsnprintf(msg, sizeof (msg), fmt, ap);
    if (strstr(msg, "using text renderer module") == NULL)
        return;

    vlc_mutex_lock(&ctx->lock);
    ctx->text_loads++;
    vlc_cond_broadcast(&ctx->cond);
    vlc_mutex_unlock(&ctx->lock);
}

static void *video_lock(void *opaque, void **planes)
{
    (void) opaque;
    for (size_t i = 0; i < ARRAY_SIZE(pixels); i++)
        planes[i] = pixels[i];
    return NULL;
}

static void video_display(void *opaque, void *picture)
{
    struct ctx *ctx = opaque;
    (void) picture;

    vlc_mutex_lock(&ctx->lock);
    ctx->frames++;
    vlc_cond_broadcast(&ctx->cond);
    vlc_mutex_unlock(&ctx->lock);
}

/* Plays the media until FRAMES pictures are displayed;
 * returns the number of text renderer loads */
static unsigned play(const char *mrl)
{
    static const char *argv[] = {
        "-v", "--aout=adummy", "--text-renderer=tdummy",
        "--no-video-title-show",
    };
    struct ctx ctx = { .text_loads = 0 };
    vlc_mutex_init(&ctx.lock);
    vlc_cond_init(&ctx.cond);

    libvlc_instance_t *vlc = libvlc_new(ARRAY_SIZE(argv), argv);
    assert(vlc != NULL);
    libvlc_log_set(vlc, on_log, &ctx);

    libvlc_media_player_t *mp = libvlc_media_player_new(vlc, NULL, NULL);
    assert(mp != NULL);
    libvlc_video_set_callbacks(mp, video_lock, NULL, video_display, &ctx);
    libvlc_video_set_format(mp, "I420", WIDTH, HEIGHT, WIDTH);

    libvlc_media_t *md = libvlc_media_new_location(mrl);
    assert(md != NULL);
    libvlc_media_player_set_media(mp, md);
    libvlc_media_release(md);

    libvlc_media_player_play(mp);

    vlc_tick_t deadline = vlc_tick_now() + VLC_TICK_FROM_SEC(5);
    vlc_mutex_lock(&ctx.lock);
    while (ctx.frames < FRAMES)
        if (vlc_cond_timedwait(&ctx.cond, &ctx.lock, deadline))
            break;
    /* Without displayed pictures, the test checks nothing */
    assert(ctx.frames >= FRAMES);
    vlc_mutex_unlock(&ctx.lock);

    libvlc_media_player_stop_async(mp);
    libvlc_media_player_release(mp);
    libvlc_release(vlc);

    return ctx.text_loads;
}

int main(void)
{
    test_init();

    /* The text renderer is preloaded once the vout is attached to the input,
     * so that the first subtitle is not late, but only once */
    unsigned loads = play("mock://video_track_count=1;length=10000000;"
                          "video_width=64;video_height=64");
    if (loads != 1)
    {
        test_log("FAIL: text renderer loaded %u times, expected once\n",
                 loads);
        return 1;
    }
    return 0;
}
