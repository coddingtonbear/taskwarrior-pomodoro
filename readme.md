# Taskwarrior-Pomodoro

![](http://coddingtonbear-public.s3.amazonaws.com/github/taskwarrior-pomodoro/screenshot.png)

A simple application allowing you to use Pomodoro techniques with Taskwarrior on OSX.

## Installation

You can [download the latest release here](http://coddingtonbear-public.s3.amazonaws.com/github/taskwarrior-pomodoro/releases/taskwarrior-pomodoro-1.0.0.dmg), and install it by dragging the application into your Applications directory.

## Configuration 

Although very little configuration is currently provided, but you can configure Taskwarrior Pomodoro by adding lines to your `~/.taskrc` file. 

### Task List Filter

By default, the list of tasks is limited to displaying only tasks that are currently pending (`status:pending`), but you can specify any filter you'd like for further reducing that list by setting the key `pomodoro.defaultFilter` in your `~/.taskrc`.

While at work, for example, you could limit your tasks to only pending tasks having the `work` tag by adding a line as follows:

```
pomodoro.defaultFilter=+work
```

Note that taskwarrior filters can be quite complex (although my specific use of this feature will not be particularly helpful, it may help you come to terms with what is possible by knowing that the one I used for generating the above screenshot was `pomodoro.defaultFilter=(intheamtrellolistid:5591ecedb12a520b50d2e8b8 or intheamtrellolistid:559173de3295c9b2e550243f or intheamtrellolistid:55aee69377ccc07e295462a3) and (-GAG)`) and are thus outside the scope of this document, but you can [find more information about filters in Taskwarrior's documentation](http://taskwarrior.org/docs/filter.html).
