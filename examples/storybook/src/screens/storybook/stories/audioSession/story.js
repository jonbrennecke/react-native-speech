// @flow
import React from 'react';
import { SafeAreaView, Button } from 'react-native';
import { storiesOf } from '@storybook/react-native';
import { withKnobs } from '@storybook/addon-knobs';
import { Provider } from 'react-redux';
import { queryVideos, authorizeMediaLibrary } from '@jonbrennecke/react-native-media';
import { beginSpeechTranscriptionOfAsset, createSpeechStateHOC, requestSpeechPermissions } from '@jonbrennecke/react-native-speech';

import { createReduxStore } from './speechStore';

const styles = {
  flex: {
    flex: 1,
  },
  center: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  }
};

const store = createReduxStore();

const wrapWithSpeechState = createSpeechStateHOC(state => state.speech);

const StoryComponent = wrapWithSpeechState(({
  speechTranscriptionStatus,
  speechTranscriptionAvailability,
}) => {
  const start = async () => {
    await authorizeMediaLibrary();
    await requestSpeechPermissions();
    const assets = await queryVideos({ limit: 1 });
    if (!assets.length) {
      throw 'Could not find a video';
    }
    const asset = assets[0];
    await beginSpeechTranscriptionOfAsset(asset.assetID);
  }
  const disabled = speechTranscriptionStatus !== 'ready' || !speechTranscriptionAvailability;
  return (
    <SafeAreaView style={styles.center}>
      <Button
        disabled={disabled}
        title="Start"
        onPress={start}
      />
    </SafeAreaView>
  );
});

const stories = storiesOf('Speech', module);
stories.addDecorator(withKnobs);
stories.add('Audio Session', () => (
  <Provider store={store}>
    <StoryComponent/>
  </Provider>
));
