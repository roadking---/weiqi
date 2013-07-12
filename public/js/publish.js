// Generated by CoffeeScript 1.6.2
(function() {
  window.update_comment = function(comment) {
    var c, current, text, _ref, _ref1;

    c = $("<div _type='game_comment' class='blog row'/>").append("<div class='text'>" + comment.text + "</div>").append("<a class='author' href='/u/" + comment.author + "'>" + ((_ref = comment.nickname) != null ? _ref : $('#blogs').attr('_me')) + "</span>").append("<a class='step' _step='" + comment.step + "'>" + (Number(comment.step) + 1) + "</span>").append("<span class='ts'>" + comment.ts + "</span>").prependTo('#blogs');
    if (comment.snapshots) {
      text = c.find('.text').text();
      _.each(comment.snapshots, function(x, i) {
        return text = text.replace("[G" + (i + 1) + "]", "<a class='snapshot'>[G" + (i + 1) + "]</a>");
      });
      c.find('.text').html(text);
      current = (_ref1 = $('#gaming-board').data('data').get_moves()) != null ? _ref1.current : void 0;
      if (!current) {
        return;
      }
      return c.find('.text .snapshot').each(function(i) {
        var moves, show_big_chart, _i, _ref2, _ref3, _results;

        $(this).data('snapshot', comment.snapshots[i]);
        moves = _.flatten([current.slice(0, +comment.snapshots[i].from + 1 || 9e9), comment.snapshots[i].moves], true);
        $(this).click(show_big_chart = function() {
          var b, snapshot;

          $('#tabs.nav a#trying').click();
          snapshot = $(this).data('snapshot');
          b = $('#trying-board').data('data');
          b.board.data('final_step', b.show_steps_to = snapshot.from);
          b.redraw();
          return _.each(snapshot.moves, function(x) {
            return b.on_click(x.pos, x.player);
          });
        });
        return thumbnail(moves, {
          focus: (function() {
            _results = [];
            for (var _i = _ref2 = comment.snapshots[i].from + 1, _ref3 = moves.length - 1; _ref2 <= _ref3 ? _i <= _ref3 : _i >= _ref3; _ref2 <= _ref3 ? _i++ : _i--){ _results.push(_i); }
            return _results;
          }).apply(this),
          title: "G" + (i + 1)
        }).appendTo(c).data('snapshot', comment.snapshots[i]).click(show_big_chart);
      });
    }
  };

  window.install_pub = function(type) {
    $('#pub button#submit').click(function() {
      var comment, comments, game, next_id, snapshot_list, step, text, _base, _ref, _ref1;

      snapshot_list = $(this).parent().data('snapshots');
      $(this).parent().data('snapshots', null);
      text = $.trim($(this).parent().find('textarea').val());
      if (!text || text === '') {
        return;
      }
      game = $('#gaming-board').data('data');
      step = $('#tabs a#trying').parent().hasClass('active') ? $('#trying-board').data('final_step') : game.status_quo().step;
      comments = (_ref = (_base = game.initial).comments) != null ? _ref : _base.comments = {};
      if ((_ref1 = comments[step]) == null) {
        comments[step] = {
          next_id: 0
        };
      }
      next_id = comments[step].next_id;
      comments[step][next_id] = comment = {
        id: next_id,
        ts: new Date().getTime(),
        text: text,
        step: step,
        gid: game.id,
        author: $(this).parent().attr('uid')
      };
      if (snapshot_list) {
        comment.snapshots = snapshot_list;
      }
      comments[step].next_id++;
      $(this).parent().find('textarea').val('');
      switch (type) {
        case 'dapu':
          localStorage.dapu = JSON.stringify(game.initial);
          break;
        case 'connected':
          delete comment.id;
          game = $('#gaming-board').data('data');
          if (game.connected) {
            game.send_comment($('#gaming-board').attr('socket'), comment);
          } else {
            $.post('/comment', {
              comment: comment,
              game: $('#gaming-board').attr('socket')
            }, function(rlt) {
              return console.log(rlt);
            });
          }
      }
      comment.ts = moment(Number(comment.ts)).format('YYYY/MM/DD HH:mm');
      return update_comment(comment);
    });
    return $('#pub button#add_chart').click(function() {
      var from, snapshot, snapshot_list, text, _ref;

      if ($('#tabs a#trying').parent().hasClass('active')) {
        from = $('#trying-board').data('final_step');
        snapshot = {
          moves: $('#trying-board').data('data').get_moves().current.slice(from + 1),
          from: from
        };
        console.log(snapshot_list = (_ref = $(this).parent().data('snapshots')) != null ? _ref : []);
        snapshot_list.push(snapshot);
        $(this).parent().find('textarea').val(text = $(this).parent().find('textarea').val() + ("[G" + snapshot_list.length + "]"));
        return $(this).parent().data('snapshots', snapshot_list);
      } else {
        return $('#tabs a#trying').click();
      }
    });
  };

  window.clear_pub_input = function() {
    $('#pub').data('snapshots', null);
    return $('#pub textarea').val('');
  };

}).call(this);
