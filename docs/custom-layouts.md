# Custom Layouts (beta)

Mon supports implementing custom layouts via JavaScript.

## Installing

Layouts are located in `~/Library/Application Support/Mon/Layouts/`. This directory is automatically created when Mon is first launched. JavaScript files in this directory will automatically be picked up and keyed by the name of the file; e.g., `my-cool-layout.js` will be available as a layout with the key `my-cool-layout`.

At the moment, files must be manually moved to this directory. There is no way to import them through the app.

## Per-display and per-Space selection

The enabled layout list is global, but the selected layout and its state are
stored separately for every **display × Space** pair. For example, the same
physical display can use Equal Row in one desktop and Wide in another, while
an external display can use Tall at the same time.

Open the status-menu **Layouts** submenu after focusing a window on the target
display. Its disabled first line identifies the target display and Space. If
there is no focused window, the menu uses the display under the mouse cursor.
A layout selection is persisted immediately; it does not need to wait for
Mon to quit.

## Defining a Layout

At the root of the file you must define a function named `layout`. This function should return an object with the following properties.

### Layout Properties

#### `name`

A string defining the name of the layout. If no name is specified it will default to the layout key.

#### `initialState`

An object defining any initial state to be tracked by the layout.

#### `commands`

An object defining the commands the layout responds to. There are four available custom commands keyed as `command1`, `command2`, `command3`, and `command4`, in addition to paned layout commands keyed as `expandMain`, `shrinkMain`, `increaseMain`, and `decreaseMain`. Commands are objects with a `description` string to describe what the command does and an `updateState` function.

The `updateState` function takes two arguments—`state` and `focusedWindowID`—and must return a new state object.

* `state`: the current layout state
* `focusedWindowID`: the currently focused window

#### `extends`

The key for a layout that the custom layout extends. Each call to `getFrameAssignments` will include the frames determined by the extended layout for reference. There are some limitations to this extension—you cannot affect the state of the extended layout, for example—but this is useful for small modifications to existing native layout algorithms.

#### `getFrameAssignments`

A function that takes four arguments—`windows`, `screenFrame`, `state`, and `extendedFrames`—and returns a mapping of window ids to window frames.

* `windows`: the list of active windows on the screen
* `screenFrame`: the frame of the screen containing the layout
* `state`: the current layout state
* `extendedFrames`: the frames that are inherited from the extended layout if any is defined

The return should be an object with _new_ frames keyed by the window id.

#### `updateWithChange`

A function that takes two arguments—`change` and `state`—and must return a new layout state based on the provided change.

* `change`: the particular change the layout needs to respond to.

#### `recommendMainPaneRatio`

A function that takes two arguments—`ratio` and `state`—and must return a new layout state based on the recommended ratio.

* `ratio`: the ratio recommended for the layout based on windows being resized by mouse controls.

### Mouse Resizing

Mon supports changing the relative ratios of windows when changing the size of windows by dragging them with the cursor. By default, these ratios are recommended by calling the `recommendMainPaneRatio` layout property, and happen on the horizontal axis. When the window is resized, the system determines what ratio is appropriate for the new width given the dimensions of the screen it is on. These values are clamped to [0, 1].

To scale along a different axis, you can specify the `unconstrainedDimension` and `isMain` properties of each window's frame. The dimension determines the axis along which window frame changes will cause recommended ratio changes, and the `isMain` property determines which part of the ratio the window applies to.

Note that currently the recommended ratio is global to the layout and not specific to a given window, so it is not particularly meaningful to specify multiple `unconstrainedDimension` values among frames.

### Common Structures

#### Windows

A window is an object with three properties.

* `id`: an opaque identifier for referencing the window both within `getFrameAssignments` and across the layout state
* `frame`: the current frame of the window in the screen space
* `isFocused`: boolean for whether or not the window is currently focused

#### Frames

A frame is an object with four required properties and two optional properties.

* `x`: x-coordinate in the screen space
* `y`: y-coordinate in the screen space
* `width`: pixel width
* `height`: pixel height
* (optional) `isMain`: boolean indicating whether the window is in the main pane (default: `true`)
* (optional) `unconstrainedDimension`: a string indicating on which axis the window is able to be resized via mouse (values: `horizontal`, `vertical`; default: `horizontal`)

Note that frames are in a global space, not relative to a given screen.

#### Changes

A change represents the outcome of an event in the system. It is an object with up to two properties.

* `change`: the string key of the type of event (see below)
* `windowID`: the window id for relevant changes
* `otherWindowID`: the second window id for relevant changes

Current changes are:

* `"add"`: a window has been added to tracking
    * Has a `windowID` for the new window
* `"remove"`: a window has been removed from tracking
    * Has a `windowID` for the removed window
* `"focus_changed"`: the currently focused window has changed
    * Has a `windowID` for the newly focused window
* `"window_swap"`: two windows have been swapped in position
    * Has a `windowID` for the first window and an `otherWindowID` for the second window
* `"application_activate"`: an application has been activated
    * No parameters
* `"application_deactivate"`: an application has been deactivated
    * No parameters
* `"space_change"`: the current space on a screen has changed
    * No parameters
* `"layout_change"`: the layout of a screen changed
    * No parameters
* `"unknown"`: an unknown event
    * No parameters

## Examples

There are several layouts defined for automated tests that can serve as examples. They are in [MonTests/Model/CustomLayouts/](../MonTests/Model/CustomLayouts/).

### Example: equal-height rows

The built-in Row layout reserves half of the screen for the main pane, so the
first window is larger. To give every window an equal-height row, save this as
`~/Library/Application Support/Mon/Layouts/equal-row.js`:

```js
function layout() {
  return {
    name: "Equal Row",
    initialState: {},
    getFrameAssignments: function(windows, screenFrame, state, extendedFrames) {
      var frames = {};
      var count = windows.length;

      if (count === 0) {
        return frames;
      }

      var baseHeight = Math.floor(screenFrame.height / count);

      windows.forEach(function(window, index) {
        var isLast = index === count - 1;
        var height = isLast ? screenFrame.height - baseHeight * index : baseHeight;

        frames[window.id] = {
          x: screenFrame.x,
          y: screenFrame.y + baseHeight * index,
          width: screenFrame.width,
          height: height,
          isMain: true,
          unconstrainedDimension: "vertical"
        };
      });

      return frames;
    },
    updateWithChange: function(change, state) {
      return state;
    },
    recommendMainPaneRatio: function(ratio, state) {
      return state;
    }
  };
}
```

Then enable `Equal Row` in Preferences → Layouts, or add `equal-row` to the
`layouts` list in `~/.mon.yml`. Restart Mon after adding the file so
the layout is discovered.

For the built-in Row layout, an alternative is to increase the main pane count
until it equals the number of windows (`Increase main pane count`, default
`mod1 + ,`); then every row gets the same height.
