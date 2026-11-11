/*****************************************************************************
 * resource.h
 *****************************************************************************
 * Copyright (C) 2008 Laurent Aimar
 *
 * Authors: Laurent Aimar < fenrir _AT_ videolan _DOT_ org >
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
 *****************************************************************************/

#ifndef LIBVLC_INPUT_RESOURCE_H
#define LIBVLC_INPUT_RESOURCE_H 1

#include <vlc_common.h>
#include <vlc_mouse.h>
#include "../video_output/vout_internal.h"

enum input_resource_vout_state
{
    INPUT_RESOURCE_VOUT_NOTCHANGED,
    INPUT_RESOURCE_VOUT_STARTED,
    INPUT_RESOURCE_VOUT_STOPPED,
};

/**
 * This function set the associated input.
 */
void input_resource_SetInput( input_resource_t *, input_thread_t * );

/**
 * \return the current audio output if any.
 * Use aout_Release() to drop the reference.
 */
audio_output_t *input_resource_HoldAout( input_resource_t * );

/**
 * This function creates or recycles an audio output.
 */
audio_output_t *input_resource_GetAout( input_resource_t * );

/**
 * This function retains or destroys an audio output.
 */
void input_resource_PutAout( input_resource_t *, audio_output_t * );

/**
 * This function handles sout request.
 */
sout_stream_t *input_resource_RequestSout( input_resource_t *, const char * );
void input_resource_PutSout(input_resource_t *, sout_stream_t *);

vout_thread_t *input_resource_RequestVout(input_resource_t *, vlc_video_context *,
                                         const vout_configuration_t *,
                                         enum vlc_vout_order *order,
                                         enum input_resource_vout_state *vout_state);
void input_resource_PutVout(input_resource_t *, vout_thread_t *,
                            enum input_resource_vout_state *vout_state);

/**
 * This function returns one of the current vout if any.
 *
 * You must call vout_Release() on the value returned (if non NULL).
 */
vout_thread_t *input_resource_HoldVout( input_resource_t * );

/**
 * State of an input_resource_WaitStartedVout() caller, only written by
 * input_resource_ResetVoutWait() and input_resource_CancelVoutWait()
 */
struct input_resource_vout_wait
{
    vlc_tick_t since;
    bool cancelled;
};

/**
 * This function returns a started vout, unlike input_resource_HoldVout()
 * which can return the stopped vout kept for reuse.
 *
 * Without any started vout, it waits for one as long as a video decoder may
 * start it: until the timeout has elapsed after the last reset of the wait
 * state or after the last signal of a video decoder (see
 * input_resource_SignalVideoDecoder()), whichever is later, unless the wait
 * is cancelled.
 *
 * You must call vout_Release() on the value returned (if non NULL).
 */
vout_thread_t *input_resource_WaitStartedVout(input_resource_t *,
                                const struct input_resource_vout_wait *,
                                vlc_tick_t timeout);

/**
 * This function resets a wait state, when its caller starts or restarts:
 * its waits are no longer cancelled, and their timeout starts again.
 */
void input_resource_ResetVoutWait(input_resource_t *,
                                  struct input_resource_vout_wait *);

/**
 * This function cancels the current and next waits of a wait state, until it
 * is reset.
 */
void input_resource_CancelVoutWait(input_resource_t *,
                                   struct input_resource_vout_wait *);

/**
 * This function signals that a video decoder may start a vout soon, with its
 * first picture: when it is created or resumed before that picture, or when
 * it is deleted, since another decoder can replace it.
 */
void input_resource_SignalVideoDecoder(input_resource_t *);

/**
 * This function returns the dummy vout. It will be the parent of the future
 * main vout and can be used to pre-configure it. */
vout_thread_t *input_resource_HoldDummyVout( input_resource_t * );

/**
 * This function returns all current vouts if any.
 *
 * You must call vout_Release() on all values returned (if non NULL).
 */
void input_resource_HoldVouts( input_resource_t *, vout_thread_t ***, size_t * );

void input_resource_StopFreeVout( input_resource_t * );

/**
 * This function holds the input_resource_t itself
 */
input_resource_t *input_resource_Hold( input_resource_t * );

void input_resource_ResetAout( input_resource_t * );

#endif
