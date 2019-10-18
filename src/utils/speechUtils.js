// @flow
import Bluebird from 'bluebird';
import { NativeModules, NativeEventEmitter } from 'react-native';

import type { LocaleObject } from '../state';

const { HSSpeechManager: NativeSpeechManager } = NativeModules;

export const SpeechManager = Bluebird.promisifyAll(NativeSpeechManager);

export const SpeechTranscriptionEventEmitter = new NativeEventEmitter(
  NativeSpeechManager
);

export const SpeechTranscriptionEvents = {
  didBecomeAvailable: 'speechTranscriptionDidBecomeAvailable',
  didBecomeUnavailable: 'speechTranscriptionDidBecomeUnavailable',
  didChangeLocale: 'speechTranscriptionDidChangeLocale',
  didOutput: 'speechTranscriptionDidOutput',
  didNotDetectSpeech: 'speechTranscriptionDidNotDetectSpeech',
  didBegin: 'speechTranscriptionDidBegin',
  didEnd: 'speechTranscriptionDidEnd',
  didFail: 'speechTranscriptionDidFail',
};

export const beginSpeechTranscriptionOfAsset = async (
  assetID: string
): Promise<boolean> => {
  return SpeechManager.beginSpeechTranscriptionOfAssetAsync(assetID);
};

export const beginSpeechTranscriptionOfAudioSession = async (
  uniqueID: string
): Promise<boolean> => {
  return SpeechManager.beginSpeechTranscriptionOfAudioSessionAsync(uniqueID);
};

// eslint-disable-next-line flowtype/generic-spacing
export const endSpeechTranscriptionOfAudioSession = async (): Promise<
  boolean
> => {
  return SpeechManager.endSpeechTranscriptionOfAudioSessionAsync();
};

export const requestSpeechPermissions = async (): Promise<boolean> => {
  return SpeechManager.requestSpeechPermissionsAsync();
};

export const hasSpeechPermissions = async (): Promise<boolean> => {
  return SpeechManager.hasSpeechPermissionsAsync();
};

export const getSupportedLocales = async (): Promise<LocaleObject[]> => {
  return SpeechManager.getSupportedLocalesAsync();
};

export const getCurrentLocale = async (): Promise<LocaleObject> => {
  return SpeechManager.getCurrentLocaleAsync();
};

export const setSpeechLocale = async (
  localeIdentifier: string
): Promise<boolean> => {
  return await SpeechManager.setLocaleAsync(localeIdentifier);
};
