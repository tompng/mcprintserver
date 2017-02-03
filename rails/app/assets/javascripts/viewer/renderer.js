
$(function(){
  var renderer = null
  $(document).on('turbolinks:load', function(){
    if(renderer){
      renderer.terminate()
      renderer = null
    }
    var $preview = $('#preview')
    if(!$preview.length)return
    function load(){
      renderer = new Renderer($preview.data('objfile'), $preview, function(){
        $('#preview .loading').hide()
      })
    }
    load()
    $preview.on('reload', function(){
      renderer.terminate()
      $('#preview .loading').show()
      $('#preview canvas').remove()
      load()
    })
  })
  $(document).on('click', '#preview_reload', function(){
    var objfile = $(this).data('objfile')
    window.obob=objfile
    if(objfile){
      objfile += (objfile.indexOf('?')>=0 ? '&' : '?')+Math.random()
      $('#preview').data('objfile', objfile)
    }
    $('#preview').trigger('reload')
  })
})

function Renderer(objfile, $el, loadCallback){
  var renderer = new THREE.WebGLRenderer()
  var camera = new THREE.PerspectiveCamera(45, 1, 1, 1000)
  var scene = new THREE.Scene()
  var ambient = new THREE.AmbientLight(0xffffff, 0.5)
  var backLight = new THREE.DirectionalLight(0xffffff, 1.0)
  backLight.position.set(100, 0, -100).normalize()
  backLight.castShadow = true
  backLight.shadowMapWidth = 1024
  backLight.shadowMapHeight = 1024
  var d = 2;
	backLight.shadowCameraLeft = -d
	backLight.shadowCameraRight = d
	backLight.shadowCameraTop = d
	backLight.shadowCameraBottom = -d
  scene.add(ambient);
  scene.add(backLight);
  camera.position.z = 3;
  var light2 = new THREE.DirectionalLight(0xffffff, 0.5)
  light2.position.set(1,2,3).normalize()
  scene.add(light2)
  var light3 = new THREE.DirectionalLight(0xffffff, 0.25)
  light3.position.set(-1,-2,-3).normalize()
  scene.add(light3)
  renderer.shadowMapEnabled = true
  $el.append(renderer.domElement)
  var controls = new THREE.OrbitControls(camera, renderer.domElement)
  controls.enableDamping = true
  controls.dampingFactor = 0.25
  controls.enableZoom = false
  var mtlLoader = new THREE.MTLLoader();
  mtlLoader.setBaseUrl('/');
  mtlLoader.setPath('/');
  var mtlfile = 'block.mtl'
  mtlLoader.load(mtlfile, function (mtl) {
    mtl.preload();
    var objLoader = new THREE.OBJLoader();
    objLoader.setMaterials(mtl);
    objLoader.load(objfile, function (object) {
      if(loadCallback)loadCallback()
      object.children[0].castShadow = true
      object.children[0].receiveShadow = true
      scene.add(object)
    })
  })
  var terminated = false
  function animate() {
    if(terminated)return
  	var t=performance.now()/1000/4
  	backLight.position.set(2*Math.cos(t), 2, 2*Math.sin(t))
    requestAnimationFrame(animate)
    var w = $el.width()
    var h = $el.height()
    camera.aspect = w / h
    camera.updateProjectionMatrix()
    renderer.setSize(w, h)
    controls.update()
    renderer.render(scene, camera)
  }
  this.terminate = function(){terminated = true}
  animate()
}
