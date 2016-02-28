# Taskwarrior-Pomodoro

![](http://coddingtonbear-public.s3.amazonaws.com/github/taskwarrior-pomodoro/screenshot.png)

A simple application allowing you to use Pomodoro techniques with Taskwarrior on OSX.

## Installation

You can [download the latest release here](http://coddingtonbear-public.s3.amazonaws.com/github/taskwarrior-pomodoro/releases/taskwarrior-pomodoro-1.3.0.dmg), and install it by dragging the application into your Applications directory.

## Configuration 

Configuring Taskwarrior Pomodoro is handled by adding lines to your `~/.taskrc` file.  See below for what features you can configure.

### Task List Filter

By default, the list of tasks is limited to displaying only tasks that are currently pending (`status:pending`), but you can specify any filter you'd like for further reducing that list by setting the key `pomodoro.defaultFilter` in your `~/.taskrc`.

While at work, for example, you could limit your tasks to only pending tasks having the `work` tag by adding a line as follows:

```
pomodoro.defaultFilter=+work
```

Note that taskwarrior filters can be quite complex (although my specific use of this feature will not be particularly helpful, it may help you come to terms with what is possible by knowing that the one I used for generating the above screenshot was `pomodoro.defaultFilter=(intheamtrellolistid:5591ecedb12a520b50d2e8b8 or intheamtrellolistid:559173de3295c9b2e550243f or intheamtrellolistid:55aee69377ccc07e295462a3) and (-work)`) and are thus outside the scope of this document, but you can [find more information about filters in Taskwarrior's documentation](http://taskwarrior.org/docs/filter.html).

### Post-Pomodoro Hook

* [Taskwarrior-Pomodoro-Beeminder](https://github.com/coddingtonbear/taskwarrior-pomodoro-beeminder) provides functionality allowing you to increment Beeminder goals using this "Post-Pomodoro Hook" functionality.

You can configure Taskwarrior Pomodoro to call a script of your choice after you complete a Pomodoro.  The script will receive one additional command-line argument: the UUID of the task that you were working on.  You could use this for a variety of things, including updating goal-tracking software or recording billable hours.

```
pomodoro.postCompletionCommand=/path/to/my/script
```

### Pomodoro Duration

By default, Taskwarrior Pomodoro uses standard 25-minute (1,500 second) pomodoros.  You can override the default duration by adding a setting named ``pomodoro.durationSeconds`` setting the number of seconds you'd like a pomodoro to last.  For example; to set your pomodoros to last 45 minutes (2,700 seconds), you could set this setting as follows:

```
pomodoro.durationSeconds=2700
```
