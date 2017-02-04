$(function(){
  $(document).on('input change', '#keyword_search', function(){
    var keywords = $(this).val().split(/[ 　,、\t]+/).filter(function(a){return a})
    $('.area').removeClass('search-hit')
    console.log(keywords)
    if(keywords.length==0)return
    $('.area').each(function(){
      var $el = $(this)
      var aid = $el.data('area-id')
      var data = $el.data('keywords')
      hit=true
      console.log(aid)
      keywords.forEach(function(word){
        if(aid==word||aid==word.replace('-','_'))return
        if(!data||data.indexOf(word)<0)hit=false
      })
      if(hit)$el.addClass('search-hit')
    })

  })
})
