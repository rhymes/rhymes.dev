---
date: 2018-03-16T10:51:42Z
description: Using structured logging, Rails and ANSI colors
slug: logging-rails-requests-with-structure-and-colors
tags: [rails, ruby, logging]
title: Logging Rails requests with structure and colors
---

In a [related post about Flask and Python]({{< ref "20180316-logging-flask-requests-with-colors-and-structure" >}}) I explained how to structure request logs in Python with a sprinkle of colors.

Rails already has the great [lograge](https://github.com/roidrage/lograge) but how can we leverage it and add ANSI colors to the strings?

Fortunately lograge supports custom formatters with:

```ruby
Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.formatter = YourOwnFormatter.new
end
```

so I just created a new formatter to add colors like this:

```ruby
require 'colorized_string'

class ColorKeyValue < Lograge::Formatters::KeyValue
  FIELDS_COLORS = {
    method: :red,
    path: :red,
    format: :red,
    controller: :green,
    action: :green,
    status: :yellow,
    duration: :magenta,
    view: :magenta,
    db: :magenta,
    time: :cyan,
    ip: :red,
    host: :red,
    params: :green
  }

  def format(key, value)
    line = super(key, value)

    color = FIELDS_COLORS[key] || :default
    ColorizedString.new(line).public_send(color)
  end
end
```

I admit that color coding each parameter might be a little too much but I'm having fun :-D

`require 'colorized_string'` and `ColorizedString` are part of the [colorize](https://github.com/fazibear/colorize) library.

This is the result:

![colorized logging](https://thepracticaldev.s3.amazonaws.com/i/uul3vln56n30ror4ncyi.png)
