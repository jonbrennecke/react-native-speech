// @flow
import type { ISpeechState } from './';

export const selectors = {
  selectSpeechTranscriptionAvailability: (state: ISpeechState) =>
    state.getSpeechTranscriptionAvailability(),

  selectSpeechTranscriptionStatus: (state: ISpeechState) =>
    state.getSpeechTranscriptionStatus(),

  selectSpeechTranscriptions: (state: ISpeechState) =>
    state.getSpeechTranscriptions(),
};
