// @flow
import { Map } from 'immutable';

import { createReducer } from './createReducer';
import { createSpeechState } from './speechState';

import type {
  SpeechTranscriptionStatus,
  SpeechTranscription,
  ISpeechState,
} from './';
import type { Action } from '../types';

const SpeechState = createSpeechState({
  speechTranscriptionStatus: null,
  speechTranscriptionAvailability: true,
  speechTranscriptions: new Map(),
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

  setSpeechTranscriptions: (
    state,
    {
      payload,
    }: Action<{ speechTranscriptions: Map<string, SpeechTranscription> }>
  ): ISpeechState => {
    if (!payload) {
      return state;
    }
    return state.setSpeechTranscriptions(payload.speechTranscriptions);
  },

  setSpeechTranscription: (
    state,
    {
      payload,
    }: Action<{ key: string, speechTranscription: SpeechTranscription }>
  ): ISpeechState => {
    if (!payload) {
      return state;
    }
    return state.setSpeechTranscription(
      payload.key,
      payload.speechTranscription
    );
  },
};

export const {
  reducer,
  actionCreators: identityActionCreators,
} = createReducer(initialState, reducers);
