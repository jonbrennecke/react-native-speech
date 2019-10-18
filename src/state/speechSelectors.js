// @flow
import type { ISpeechState } from './';

export const selectors = {
  selectSpeechTranscriptionAvailability: (state: ISpeechState) =>
    state.getSpeechTranscriptionAvailability(),

  selectSpeechTranscriptionStatus: (state: ISpeechState) =>
    state.getSpeechTranscriptionStatus(),

  selectSpeechTranscriptions: (state: ISpeechState) =>
    state.getSpeechTranscriptions(),

  selectSpeechTranscriptionErrors: (state: ISpeechState) =>
    state.getSpeechTranscriptionErrors(),

  selectSpeechTranscriptionIDsWithNoSpeechDetected: (state: ISpeechState) =>
    state.getSpeechTranscriptionIDsWithNoSpeechDetected(),

  selectLocale: (state: ISpeechState) => state.getLocale(),

  selectSupportedLocales: (state: ISpeechState) => state.getSupportedLocales(),
};
