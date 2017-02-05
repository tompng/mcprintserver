// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or any plugin's vendor/assets/javascripts directory can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file. JavaScript code in this file should be added after the last require_* statement.
//
// Read Sprockets README (https://github.com/rails/sprockets#sprockets-directives) for details
// about supported directives.
//
//= require jquery
//= require jquery_ujs
//= require turbolinks
//= require_tree .

$(function(){
  $(document).on('turbolinks:load', function(){
    componentHandler.upgradeDom()
  })
})

$(function(){
  $(document).on('turbolinks:load', function(){
    var timer = setInterval(function(){
      var $messages = $('.flash-messages')
      if($messages.length==0){
        clearInterval(timer)
        return
      }
      $messages.each(function(){
        var $el = $(this)
        var time = $el.data('decay-started')
        if(time===undefined)$el.data('decay-started', time=new Date())
        var opacity=(time-new Date())/1000+4
        if(opacity<0){
          $el.remove()
        }else{
          $el.css({opacity: Math.min(opacity, 1)})
        }
      })
    }, 10)
  })
})

$(function(){
  $(document).on('click', 'input[readonly]', function(){
    if(this.select)this.select()
    if(this.setSelectionRange)this.setSelectionRange(0, this.value.length)
  })
})

$(function(){
  var cnt=0
  function run(){
    cnt++
    if(cnt%10==0)setTimeout(run,3000)
    else setTimeout(run, 32)
    var phase = cnt%10/10
    var page = Math.floor(cnt/10)
    $('.slides').each(function(){
      var $el = $(this)
      var $slides = $el.find('.slide')
      $slides.css({display:'none'})
      $prev = $slides.eq((page-1)%$slides.length)
      $current = $slides.eq(page%$slides.length)
      $prev.css({display:'block',zIndex:'',opacity:1-phase})
      $current.css({display:'block',zIndex:1,opacity:phase})
    })
  }
  run()
})
