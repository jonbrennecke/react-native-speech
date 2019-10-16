// @flow
import React from 'react';
import { SafeAreaView, Button } from 'react-native';
import { storiesOf } from '@storybook/react-native';
import { withKnobs } from '@storybook/addon-knobs';

import { beginSpeechTranscriptionOfAudioSession } from '@jonbrennecke/react-native-speech';

const styles = {
  flex: {
    flex: 1,
  },
};

const stories = storiesOf('Speech', module);
stories.addDecorator(withKnobs);
stories.add('Audio Session', () => (
  <SafeAreaView style={styles.flex}>
    <Button
      title="Start"
      onPress={beginSpeechTranscriptionOfAudioSession}
    />
  </SafeAreaView>
));
