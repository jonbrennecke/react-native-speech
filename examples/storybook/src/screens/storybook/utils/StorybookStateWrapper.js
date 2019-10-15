// @flow
import { PureComponent } from 'react';

import type { Element } from 'react';

export type StorybookStateWrapperProps<S: Object> = {
  initialState: S,
  // eslint-disable-next-line flowtype/space-after-type-colon
  onMount?:
    | ((getState: () => S, setState: ($Shape<S>) => void) => void)
    | ((getState: () => S, setState: ($Shape<S>) => void) => Promise<void>),
  render: (getState: () => S, setState: ($Shape<S>) => void) => ?Element<*>,
};

export type StorybookStateWrapperState<S: Object> = S;

export class StorybookStateWrapper<S: Object> extends PureComponent<
  StorybookStateWrapperProps<S>,
  StorybookStateWrapperState<S>
> {
  constructor(props: StorybookStateWrapperProps<S>) {
    super(props);
    this.state = props.initialState;
  }

  async componentDidMount() {
    if (this.props.onMount) {
      await this.props.onMount(this.state, state => this.setState(state));
    }
  }

  render() {
    return (
      this.props.render(() => this.state, state => this.setState(state)) || null
    );
  }
}
