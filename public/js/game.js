// Generated by CoffeeScript 1.6.2
(function() {
  var Weiqi, set_seat, show_notice, _ref,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  set_seat = function(seat, player) {
    var s;

    s = $("#seats ." + seat).addClass('taken');
    return s.find('.nickname').text(player.nickname);
  };

  show_notice = function(msg) {
    $('#game-notice > *').hide();
    return $("#game-notice *[msg='" + msg + "']").show();
  };

  Weiqi = (function(_super) {
    __extends(Weiqi, _super);

    function Weiqi() {
      _ref = Weiqi.__super__.constructor.apply(this, arguments);
      return _ref;
    }

    Weiqi.prototype.on_connect = function() {
      Weiqi.__super__.on_connect.call(this);
      console.log('connected');
      show_notice('connected');
      if (this.initial.calling_finishing) {
        if (this.initial.calling_finishing.msg === 'ask' && this.initial.calling_finishing.uid === this.uid()) {
          return show_notice('ask_calling_finishing');
        } else if (this.is_player() && this.initial.calling_finishing.msg === 'ask' && this.initial.calling_finishing.uid !== this.uid()) {
          return show_notice('ask_calling_finishing_receiver');
        } else if (this.is_player() && this.initial.calling_finishing.msg === 'reject' && this.initial.calling_finishing.uid !== this.uid()) {
          return show_notice('reject_calling_finishing_receiver');
        } else if (this.is_player() && this.initial.calling_finishing.msg === 'accept') {
          if (this.initial.calling_finishing.uid === this.uid()) {
            show_notice('accept_calling_finishing');
          } else {
            show_notice('accept_calling_finishing_receiver');
          }
          if (this.initial.analysis) {
            return this.show_finishing_view(this.initial.analysis);
          }
        }
      }
    };

    Weiqi.prototype.show_finishing_view = function(analysis) {
      var _this = this;

      return _.each(analysis, function(x) {
        var item, _ref1, _ref2, _ref3;

        item = $('.finishing:visible li').first().clone().appendTo($('.finishing:visible ul')).removeClass('hide').data('regiment', x).data('stones', x.stones = _.chain(x.domains).pluck('stone_blocks').flatten().pluck('block').flatten().value()).hover(function() {
          return _this.find_stones(_.pluck(item.data('stones'), 'n')).addClass('selected');
        }, function() {
          return _this.board.find('.black, .white').each(function(i, stone) {
            return $(stone).removeClass('selected');
          });
        });
        item.find('.player').text(x.player);
        item.find('.stones').text(item.data('stones').length);
        item.find(".guess option[value='" + (((_ref1 = x.suggests) != null ? _ref1[_this.uid()] : void 0) || x.judge || x.guess) + "']").attr("selected", true);
        item.find("select.guess").change(function(e) {
          var suggest;

          suggest = $(e.target).val();
          return _this.call_finishing('suggest', item.data('stones')[0].n, suggest, function() {
            var _base, _ref2;

            if ((_ref2 = (_base = $(item).data('regiment')).suggests) == null) {
              _base.suggests = {};
            }
            $(item).data('regiment').suggests[_this.uid()] = suggest;
            if ($(item).data('regiment').suggests[_this.opponent()]) {
              if ($(item).data('regiment').suggests[_this.opponent()] === suggest) {
                $(item).data('regiment').judge = suggest;
              } else {
                $(item).data('regiment').judge = 'disagree';
              }
            } else {
              $(item).data('regiment').judge = suggest;
            }
            return _this.find_stones(_.pluck($(item).data('stones'), 'n')).removeClass('disagree live dead').addClass($(item).data('regiment').judge);
          });
        });
        if ((_ref2 = x.suggests) != null ? _ref2[_this.opponent()] : void 0) {
          if ((_ref3 = $(item)) != null) {
            _ref3.find(".opponent_guess").text(x.suggests[_this.opponent()]);
          }
        }
        console.log(x.judge || x.guess);
        _this.find_stones(_.pluck(item.data('stones'), 'n')).addClass(x.judge || x.guess);
        return item.show();
      });
    };

    Weiqi.prototype.on_disconnect = function() {
      Weiqi.__super__.on_disconnect.call(this);
      this.last_game_notice = $('#game-notice > *:visible').attr('msg');
      show_notice('connection_lost');
      return console.log('disconnect');
    };

    Weiqi.prototype.on_reconnect = function() {
      var _this = this;

      Weiqi.__super__.on_reconnect.call(this);
      console.log('reconnected');
      show_notice('reconnected');
      if (this.last_game_notice) {
        return _.delay((function() {
          return show_notice(_this.last_game_notice);
        }), 5000);
      }
    };

    Weiqi.prototype.on_connect_failed = function() {
      Weiqi.__super__.on_connect_failed.call(this);
      return show_notice('connect_failed');
    };

    Weiqi.prototype.on_connecting = function() {
      Weiqi.__super__.on_connecting.call(this);
      return show_notice('connecting');
    };

    Weiqi.prototype.on_next_player = function(player) {
      Weiqi.__super__.on_next_player.call(this, player);
      $("#players .next").removeClass('next');
      return $("#players ." + player).addClass('next');
    };

    Weiqi.prototype.on_start_taking_seat = function() {
      return location.reload();
    };

    Weiqi.prototype.on_seats_update = function(seats) {
      return _.each(['black', 'white'], function(s) {
        if (seats[s]) {
          $("#seats ." + s).addClass('taken');
          return $("#seats ." + s + " .nickname").text(seats[s].nickname);
        } else {
          return $("#seats ." + s).removeClass('me').removeClass('taken');
        }
      });
    };

    Weiqi.prototype.on_quit = function(res) {
      return location.reload();
    };

    Weiqi.prototype.on_resume = function(res) {
      return location.reload();
    };

    Weiqi.prototype.on_start = function(seats, next) {
      $('#players .black .name').text(seats.black.nickname).attr('href', "/u/" + seats.black.id);
      $('#players .black .title').text(seats.black.title);
      $('#players .white .name').text(seats.white.nickname).attr('href', "/u/" + seats.black.id);
      $('#players .white .title').text(seats.white.title);
      _.delay((function() {
        return $('#seats').hide();
      }), 5000);
      if (this.is_player()) {
        if (this.next() === this.seat()) {
          return show_notice('started_please_move');
        } else {
          return show_notice('started_please_wait');
        }
      }
    };

    Weiqi.prototype.on_click = function(pos) {
      if (this.board.attr('status') === 'started' && this.is_player() && this.next() === this.seat()) {
        Weiqi.__super__.on_click.call(this, pos);
        return show_notice('started_please_wait');
      }
    };

    Weiqi.prototype.on_move = function(moves, next) {
      if (this.board.attr('status') === 'started' && this.is_player() && next === this.seat()) {
        return show_notice('started_please_move');
      }
    };

    Weiqi.prototype.on_show_steps = function(step) {
      var _ref1;

      if (step == null) {
        step = ((_ref1 = this.initial.moves) != null ? _ref1.length : void 0) - 1;
      }
      if (step == null) {
        return;
      }
      return $('#blogs .blog').each(function(i) {
        var blog_step;

        blog_step = $(this).find('.step').attr('_step');
        if (!step || !blog_step || step >= Number(blog_step)) {
          return $(this).show();
        } else {
          return $(this).hide();
        }
      });
    };

    Weiqi.prototype.on_comment = function(comment) {
      comment.ts = moment(Number(comment.ts)).format('YYYY/MM/DD HH:mm');
      return update_comment(comment);
    };

    Weiqi.prototype.on_retract = function() {
      Weiqi.__super__.on_retract.call(this);
      show_notice('retract_by_opponent');
      return console.log('retract');
    };

    Weiqi.prototype.mine_retract = function() {
      return show_notice('started_please_move');
    };

    Weiqi.prototype.on_call_finishing = function(msg) {
      var analysis, item, stone, suggest, _base, _ref1;

      Weiqi.__super__.on_call_finishing.call(this, msg);
      switch (msg) {
        case 'ask':
          return show_notice('ask_calling_finishing_receiver');
        case 'cancel':
          return show_notice('ask_calling_finishing_cancelled');
        case 'reject':
          return show_notice('reject_calling_finishing_receiver');
        case 'accept':
          msg = arguments[0], analysis = arguments[1];
          show_notice('accept_calling_finishing_receiver');
          return this.show_finishing_view(analysis);
        case 'stop':
          if (this.next() === this.seat()) {
            return show_notice('stop_calling_finishing_receiver_move');
          } else {
            return show_notice('stop_calling_finishing_receiver_wait');
          }
          break;
        case 'suggest':
          if (this.is_player()) {
            msg = arguments[0], stone = arguments[1], suggest = arguments[2];
            console.log(arguments);
            item = _.find($('.finishing:visible ul li').toArray(), function(x) {
              return _.find($(x).data('stones'), function(y) {
                return y.n === stone;
              });
            });
            $(item).find(".opponent_guess").text(suggest);
            if ((_ref1 = (_base = $(item).data('regiment')).suggests) == null) {
              _base.suggests = {};
            }
            $(item).data('regiment').suggests[this.opponent()] = suggest;
            if ($(item).data('regiment').suggests[this.uid()]) {
              if ($(item).data('regiment').suggests[this.uid()] === suggest) {
                $(item).data('regiment').judge = suggest;
              } else {
                $(item).data('regiment').judge = 'disagree';
              }
            } else {
              console.log(334);
              $(item).data('regiment').judge = suggest;
              $(item).find(".guess option[value='" + suggest + "']").attr("selected", true);
            }
            return this.find_stones(_.pluck($(item).data('stones'), 'n')).removeClass('disagree live dead').addClass($(item).data('regiment').judge);
          }
      }
    };

    return Weiqi;

  })(ConnectedBoard);

  $(function() {
    var b, m, players, refresh_view;

    b = new Weiqi($('#gaming-board'), {
      LINE_COLOR: '#53595e',
      NINE_POINTS_COLOR: '#53595e',
      size: 600
    });
    $('#toolbox #num_btn').click(function() {
      var _ref1;

      $(this).toggleClass('show-number');
      return (_ref1 = $('#gaming-board:visible, #trying-board:visible').data('data')) != null ? _ref1.toggle_num_shown() : void 0;
    });
    $('#toolbox #beginning').click(function() {
      var _ref1;

      return (_ref1 = $('#gaming-board:visible, #trying-board:visible').data('data')) != null ? _ref1.go_to_beginning() : void 0;
    });
    $('#toolbox #ending').click(function() {
      var _ref1;

      return (_ref1 = $('#gaming-board:visible, #trying-board:visible').data('data')) != null ? _ref1.go_to_ending() : void 0;
    });
    $('#toolbox #back').click(function() {
      var _ref1;

      return (_ref1 = $('#gaming-board:visible, #trying-board:visible').data('data')) != null ? _ref1.go_back() : void 0;
    });
    $('#toolbox #forward').click(function() {
      var _ref1;

      return (_ref1 = $('#gaming-board:visible, #trying-board:visible').data('data')) != null ? _ref1.go_forward() : void 0;
    });
    $('#toolbox #retract').click(function() {
      var _ref1;

      return (_ref1 = $('#gaming-board:visible').data('data')) != null ? _ref1.retract() : void 0;
    });
    $('#toolbox #call-finishing').click(function() {
      var _ref1;

      return (_ref1 = $('#gaming-board:visible').data('data')) != null ? _ref1.call_finishing('ask', function(err) {
        if (err) {
          return console.log(err);
        } else {
          return show_notice('ask_calling_finishing');
        }
      }) : void 0;
    });
    refresh_view = function() {
      var show_num, _ref1;

      show_num = (_ref1 = $('#gaming-board:visible, #trying-board:visible').data('data')) != null ? _ref1.show_num : void 0;
      if (show_num) {
        return $('#toolbox #num_btn').removeClass('show-number');
      } else {
        return $('#toolbox #num_btn').addClass('show-number');
      }
    };
    $('#tabs a').click(function() {
      var board, final_step, game;

      if ($(this).parent().hasClass('active')) {

      } else {
        $('#tabs li').removeClass('active');
        $(this).parent().addClass('active');
        if ($(this).attr('id') === 'gaming') {
          $('#gaming-board').show();
          clear_pub_input();
          refresh_view();
        } else {
          $('#gaming-board').hide();
        }
        if ($(this).attr('id') === 'trying') {
          final_step = $('#gaming-board').data('data').get_moves().step;
          game = _.clone($('#gaming-board').data('data').initial);
          game.moves = _.chain(game.moves).filter(function(x, i) {
            return i <= final_step;
          }).map(function(x) {
            return _.clone(x);
          }).value();
          board = $('#gaming-board').clone().insertAfter($('#gaming-board')).attr('id', 'trying-board').show().data('game', game);
          board.data('final_step', final_step);
          game.title = 'Snapshot - ' + (final_step + 1);
          $('input.title').val(game.title);
          new PlayBoard(board);
          refresh_view();
        } else {
          delete $('#trying-board').data('data');
          delete $('#trying-board').data('game');
          $('#trying-board').remove();
        }
        if ($(this).attr('id') === 'surrender') {
          $('#surrender-view').show();
        } else {
          $('#surrender-view').hide();
        }
        if ($(this).attr('id') === 'detail') {
          return $('#detail-view').show();
        } else {
          return $('#detail-view').hide();
        }
      }
    });
    if (b.board.attr('status') === 'taking_seat') {
      if (b.board.attr('players')) {
        if (players = JSON.parse(b.board.attr('players'))) {
          _.chain(players).pairs().each(function(x) {
            if (x[1].id === b.uid()) {
              $("#seats ." + x[0]).addClass('taken').addClass('me');
              return $("#seats ." + x[0] + " .nickname").text($('#seats').attr('_text'));
            } else {
              $("#seats ." + x[0]).addClass('taken');
              return $("#seats ." + x[0] + " .nickname").text(x[1].nickname);
            }
          });
        }
      }
      $('#seats .black, #seats .white').click(function() {
        var seat,
          _this = this;

        if (!$(this).hasClass('taken')) {
          seat = $(this).hasClass('black') ? 'black' : 'white';
          return b.taking_seat(seat, function(res) {
            if (res === 'fail') {
              return console.log('fail');
            } else {
              if (!$('#seats .me').hasClass(seat)) {
                $('#seats .me').removeClass('me').removeClass('taken');
              }
              b.board.attr('seat', seat);
              set_seat(seat, {
                nickname: $('#seats').attr('_text')
              });
              return $(_this).addClass('me');
            }
          });
        }
      });
    }
    install_pub('connected');
    m = /step=(\d+)/.exec(location.search);
    if (m) {
      b.show_steps_to = m[1];
      b.redraw();
      b.on_show_steps(m[1]);
    } else {
      b.on_show_steps();
    }
    $('#aside-tabs a').click(function() {
      if ($(this).parent().hasClass('active')) {

      } else {
        $('#aside-tabs li').removeClass('active');
        $(this).parent().addClass('active');
        if ($(this).attr('id') === 'aside-game') {
          $('#game-controls').show();
        } else {
          $('#game-controls').hide();
        }
        if ($(this).attr('id') === 'aside-comments') {
          return $('#blogs-view').show();
        } else {
          return $('#blogs-view').hide();
        }
      }
    });
    $('#game-notice a#cancel_calling_finishing').click(function() {
      var _ref1;

      return (_ref1 = $('#gaming-board:visible').data('data')) != null ? _ref1.call_finishing('cancel', function() {
        return show_notice('started_please_move');
      }) : void 0;
    });
    $('#game-notice a#reject_calling_finishing').click(function() {
      var _ref1;

      return (_ref1 = $('#gaming-board:visible').data('data')) != null ? _ref1.call_finishing('reject', function() {
        return show_notice('reject_calling_finishing');
      }) : void 0;
    });
    $('#game-notice a#accept_calling_finishing').click(function() {
      var _ref1;

      return (_ref1 = $('#gaming-board:visible').data('data')) != null ? _ref1.call_finishing('accept', function(analysis) {
        show_notice('accept_calling_finishing');
        return b.show_finishing_view(analysis);
      }) : void 0;
    });
    return $('#game-notice a#stop_calling_finishing').click(function() {
      var _ref1;

      return (_ref1 = $('#gaming-board:visible').data('data')) != null ? _ref1.call_finishing('stop', function() {
        if (b.next() === b.seat()) {
          return show_notice('stop_calling_finishing_move');
        } else {
          return show_notice('stop_calling_finishing_wait');
        }
      }) : void 0;
    });
  });

  window.show_trying_board = function(game) {
    var board, next, tb;

    delete $('#trying-board').data('data');
    delete $('#trying-board').data('game');
    $('#trying-board').remove();
    $('#tabs li').removeClass('active');
    $('#tabs li a#trying').parent().addClass('active');
    $('#gaming-board').hide();
    next = game.next;
    board = $('#gaming-board').clone().insertAfter($('#gaming-board')).attr('id', 'trying-board').show().data('game', game);
    tb = new PlayBoard(board);
    return tb.change_to_next(next);
  };

}).call(this);
