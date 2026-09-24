/**
 * A component provider for one feature screen. AppRegistry calls the provider every time it
 * runs a surface, and a property update is a run: a component made inside the provider is a
 * new type to React each time, so every update mounted the screen afresh and took focus off
 * the field being typed in. This component is made once. What does start a screen over is a
 * new presentation — the iOS runtime keeps one surface per module and numbers every showing,
 * while Android makes a new surface each time.
 */
export function feature(Screen) {
  function Feature(props) {
    return <Screen key={props.presentation} {...props} />;
  }
  return () => Feature;
}
