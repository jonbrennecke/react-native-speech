// @flow
import { createReducer } from './createReducer';
import { createSpeechState } from './speechState';

import type { SpeechTranscriptionStatus, ISpeechState } from './';
import type { Action } from '../types';

const SpeechState = createSpeechState({
  speechTranscriptionStatus: 'ready',
  speechTranscriptionAvailability: true,
});

export const initialState = new SpeechState();

const reducers = {
  setSpeechTranscriptionStatus: (
    state,
    { payload }: Action<{ status: SpeechTranscriptionStatus }>
  ): ISpeechState => {
    if (!payload) {
      return state;
    }
    return state.setSpeechTranscriptionStatus(payload.status);
  },

  setSpeechTranscriptionAvailability: (
    state,
    { payload }: Action<{ available: boolean }>
  ): ISpeechState => {
    if (!payload) {
      return state;
    }
    return state.setSpeechTranscriptionAvailability(payload.available);
  },
};

export const {
  reducer,
  actionCreators: identityActionCreators,
} = createReducer(initialState, reducers);
