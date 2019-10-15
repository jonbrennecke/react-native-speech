
# @jonbrennecke/farrago

farrago \ fə-ˈrä-(ˌ)gō , -ˈrā- \ noun, a motley assortment of things

Farrago is a reusable template for react-native modules. It comes with a few basic things installed like eslint, prettier, flow and jest.

## Getting started

`$ npm install @jonbrennecke/farrago --save`

### Mostly automatic installation

`$ react-native link @jonbrennecke/farrago`

### Manual installation

#### iOS

1. In XCode, in the project navigator, right click `Libraries` ➜ `Add Files to [your project's name]`
2. Go to `node_modules` ➜ `r@jonbrennecke-farrago` and add `RNJonbrenneckeFarrago.xcodeproj`
3. In XCode, in the project navigator, select your project. Add `libRNJonbrenneckeFarrago.a` to your project's `Build Phases` ➜ `Link Binary With Libraries`
4. Run your project (`Cmd+R`)<

#### Android - coming soon

## Usage
```javascript
import Farrago from '@jonbrennecke/farrago';
```
  
