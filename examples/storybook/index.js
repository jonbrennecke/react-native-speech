// @flow
import { YellowBox, AppRegistry } from 'react-native';
import { StorybookUI } from './src/screens/storybook';

YellowBox.ignoreWarnings([
  'Require cycle:', // NOTE: this hides a warning from the 'core-decorators' package
  'Remote debugger is in a background tab',
  'flexWrap:'
]);

AppRegistry.registerComponent('Storybook', () => StorybookUI);
