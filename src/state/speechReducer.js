// @flow
import { Map, Set } from 'immutable';

import { createReducer } from './createReducer';
import { createSpeechState } from './speechState';

import type {
  SpeechTranscriptionStatus,
  SpeechTranscriptionError,
  SpeechTranscription,
  ISpeechState,
  LocaleObject,
} from './';
import type { Action } from '../types';

const SpeechState = createSpeechState({
  speechTranscriptionStatus: null,
  speechTranscriptionAvailability: true,
  speechTranscriptions: new Map(),
  speechTranscriptionErrors: new Map(),
  speechTranscriptionIDsWithNoSpeechDetected: new Set(),
  locale: null,
  supportedLocales: new Set(),
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
    }: Action<{ assetID: string, speechTranscription: SpeechTranscription }>
  ): ISpeechState => {
    if (!payload) {
      return state;
    }
    return state.setSpeechTranscription(
      payload.assetID,
      payload.speechTranscription
    );
  },

  setSpeechTranscriptionError: (
    state,
    {
      payload,
    }: Action<{
      assetID: string,
      speechTranscriptionError: SpeechTranscriptionError,
    }>
  ): ISpeechState => {
    if (!payload) {
      return state;
    }
    return state.setSpeechTranscriptionError(
      payload.assetID,
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

  setLocale: (
    state,
    {
      payload,
    }: Action<{
      locale: LocaleObject,
    }>
  ): ISpeechState => {
    if (!payload) {
      return state;
    }
    return state.setLocale(payload.locale);
  },

  setSupportedLocales: (
    state,
    {
      payload,
    }: Action<{
      supportedLocales: Set<LocaleObject>,
    }>
  ): ISpeechState => {
    if (!payload) {
      return state;
    }
    return state.setSupportedLocales(payload.supportedLocales);
  },
};

export const {
  reducer,
  actionCreators: identityActionCreators,
} = createReducer(initialState, reducers);
