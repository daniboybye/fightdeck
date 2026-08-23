declare module 'react-native/Libraries/Utilities/codegenNativeComponent' {
  import type { HostComponent } from 'react-native';

  export default function codegenNativeComponent<T>(
    componentName: string,
  ): HostComponent<T>;
}
