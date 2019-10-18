// @flow
import { Map, Set } from 'immutable';

import { createReducer } from './createReducer';
import { createSpeechState } from './speechState';

import type {
  SpeechTranscriptionStatus,
  SpeechTranscriptionError,
  SpeechTranscription,
  ISpeechState,
} from './';
import type { Action } from '../types';

const SpeechState = createSpeechState({
  speechTranscriptionStatus: null,
  speechTranscriptionAvailability: true,
  speechTranscriptions: new Map(),
  speechTranscriptionErrors: new Map(),
  speechTranscriptionIDsWithNoSpeechDetected: new Set(),
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

  setSpeechTranscriptionError: (
    state,
    {
      payload,
    }: Action<{
      key: string,
      speechTranscriptionError: SpeechTranscriptionError,
    }>
  ): ISpeechState => {
    if (!payload) {
      return state;
    }
    return state.setSpeechTranscriptionError(
      payload.key,
      payload.speechTranscriptionError
    );
  },

  setSpeechTranscriptionIDWithNoSpeechDetected: (
    state,
    {
      payload,
    }: Action<{
      assetID: string,
    }>
  ): ISpeechState => {
    if (!payload) {
      return state;
    }
    return state.setSpeechTranscriptionIDWithNoSpeechDetected(payload.assetID);
  },
};

export const {
  reducer,
  actionCreators: identityActionCreators,
} = createReducer(initialState, reducers);
