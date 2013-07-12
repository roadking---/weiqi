// Generated by CoffeeScript 1.6.2
(function() {
  $(function() {
    return $.each($('figure.thumb'), function() {
      var b, opts, size;

      size = $(this).parent().innerWidth() * .8;
      if (size < 20) {
        return;
      }
      console.log(size);
      console.log([$(this).parent().innerHeight(), $(this).parent().innerWidth()]);
      opts = {
        PAWN_RADIUS: Math.round(size * .7 / 38),
        NINE_POINTS_RADIUS: 2,
        LINE_COLOR: '#aaa',
        BACKGROUND_COLOR: '#fff'
      };
      opts.margin = Math.round(opts.PAWN_RADIUS * 1.4);
      opts.size = size - 2 * opts.margin;
      return b = new CanvasBoard($(this), opts);
    });
  });

}).call(this);
