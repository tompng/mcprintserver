function CubeRenderer(color){
  if(!color)color = {r: 1, g: 1, b: 1}
  function svgtag(tag){return $(document.createElementNS('http://www.w3.org/2000/svg', tag))}
  var svg = $('<svg width=256 height=256 viewBox="0 0 256 256">')
  this.svg = svg
  var matrix=[[1,0,0],[0,1,0],[0,0,1]]
  function multmm(m1,m2){
    var m=[[0,0,0],[0,0,0],[0,0,0]]
    for(var i=0;i<3;i++)for(var j=0;j<3;j++){
      for(var k=0;k<3;k++)m[i][j]+=m1[i][k]*m2[k][j]
    }
    return m
  }
  function multma(m,a){
    return [0,1,2].map(function(i){
      return m[i][0]*a[0]+m[i][1]*a[1]+m[i][2]*a[2]
    })
  }
  function multmv(m,v){
    var a=multma(m,[v.x,v.y,v.z])
    return {x:a[0],y:a[1],z:a[2]}
  }
  var face=[[-1,-1,-1],[-1,-1,+1],[-1,+1,+1],[-1,+1,-1]]
  var faces=[]
  for(var i=0;i<3;i++){
    faces.push(face.concat())
    faces.push(face.map(function(a){return [-a[0],-a[1],-a[2]]}))
    face=face.map(function(a){return [a[1],a[2],a[0]]})
  }
  function colorstr(rgb){
    return '#'+rgb.map(function(v){
      var i=Math.round(v*0xff);if(i<0)i=0;if(i>0xff)i=0xff;
      return colorstr.c16[(i>>4)&0xf]+colorstr.c16[i&0xf]
    }).join('')
  }
  colorstr.c16='0123456789abcdef'
  this.render=function(){
    svg.empty()
    faces.forEach(function(face){
      var ps=face.map(function(p){return multma(matrix,p)})
      center=[0,1,2].map(function(i){return (ps[0][i]+ps[2][i])/2})
      if(center[0]*center[0]+center[1]*center[1]+center[2]*(1/0.2+center[2])>0)return
      light=0.5-0.2*center[0]-0.3*center[1]
      var points=ps.map(function(p){
        return [128+64*p[0]/(1+0.2*p[2]),128+64*p[1]/(1+0.2*p[2])].join(',')
      }).join(' ')
      svgtag('polyline').attr({fill:colorstr([color.r*light,color.g*light,color.b*light]),points:points}).appendTo(svg)
    })
    for(var i=0;i<8*0;i++){
      var v={x:i%2*2-1,y:(i/2|0)%2*2-1,z:(i/4|0)%2*2-1}
      var p=multmv(matrix,v)
      svgtag('rect').attr({
        x: 128+64*p.x/(1+0.2*p.z)-8,
        y: 128+64*p.y/(1+0.2*p.z)-8,
        width: 16,
        height: 16,
        fill: 'blue'
      }).appendTo(svg)
    }
  }
  this.rotate = function(vec, deg){
    var l = Math.sqrt(vec.x*vec.x+vec.y*vec.y+vec.z*vec.z)
    var x=vec.x/l, y=vec.y/l, z=vec.z/l
    var c=Math.cos(deg*Math.PI/180), s=Math.sin(deg*Math.PI/180)
    var m=[
      [c+x*x*(1-c),x*y*(1-c)-z*s,x*z*(1-c)+y*s],
      [y*x*(1-c)+z*s,c+y*y*(1-c),y*z*(1-c)-x*s],
      [z*x*(1-c)-y*s,z*y*(1-c)+x*s,c+z*z*(1-c)]
    ]
    matrix=multmm(matrix,m)
  }
}

$(function(){
  $(document).on('turbolinks:load', function(){
    $('.cube').each(function(){init($(this))})
  })
  var cnt=0
  var vec={x:0,y:0,z:0}
  function init($el){
    if($el.data('renderer'))return
    var renderer = new CubeRenderer($el.data('color'))
    $el.data('renderer', renderer)
    randomize($el)
    $el.append(renderer.svg)
    renderer.rotate($el.data('vec'), 180)
    renderer.render()
  }
  function randomize($el){
    $el.data('vec', {x:2*Math.random()-1,y:2*Math.random()-1,z:2*Math.random()-1})
  }
  function cuberotate(){
    if(cnt%20==0){
      $('.cube').each(function(){randomize($(this))})
      setTimeout(cuberotate, 2000)
    }else{
      setTimeout(cuberotate,16)
    }
    var phase=(cnt%20+0.5)/20
    var angle = 120*phase*phase*(1-phase)*(1-phase)
    $('.cube').each(function(){
      var $el = $(this)
      init($el)
      var renderer = $el.data('renderer')
      renderer.rotate($el.data('vec'),angle)
      renderer.render()
    })
    cnt++
  }
  cuberotate()
})
