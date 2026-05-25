/* KOLOB site — shared nav enhancement (mobile hamburger + active link) */
(function(){
  var nav=document.querySelector('.nav'); if(!nav) return;
  var brand=nav.querySelector('.brand');
  var enter=nav.querySelector('.enter');
  var links=[].slice.call(nav.querySelectorAll('a')).filter(function(a){
    return a!==brand && a!==enter; });
  var here=(location.pathname.split('/').pop()||'index.html');
  var box=document.createElement('div'); box.className='navlinks';
  links.forEach(function(a){
    a.classList.add('lnk');
    if((a.getAttribute('href')||'')===here) a.classList.add('active');
    box.appendChild(a);
  });
  var tog=document.createElement('button');
  tog.className='navtoggle'; tog.setAttribute('aria-label','Menu'); tog.textContent='☰';
  tog.addEventListener('click',function(){ box.classList.toggle('open'); });
  nav.insertBefore(box, enter);
  nav.insertBefore(tog, enter);
  box.addEventListener('click',function(e){ if(e.target.tagName==='A') box.classList.remove('open'); });
})();

/* standardized footer links — single source of truth */
(function(){
  var links=document.querySelector('.foot .links'); if(!links) return;
  links.innerHTML=
    '<a href="index.html">Home</a>'+
    '<a href="core15.html">Core 15</a>'+
    '<a href="collection.html">Collection</a>'+
    '<a href="pitch.html">How It Works</a>'+
    '<a href="mint.html">Mint</a>'+
    '<a href="../kolob-pod-1d.html">Explore</a>';
})();

/* live tier scoreboard — base momentum + dry-run mints (FOMO) */
(function(){
  var BASE={cel:1,ter:3,tel:9};
  function counts(){
    var th=[],co=[];
    try{th=JSON.parse(localStorage.getItem('kolob:mint:thrones')||'[]');}catch(e){}
    try{co=JSON.parse(localStorage.getItem('kolob:mint:core')||'[]');}catch(e){}
    var c={cel:BASE.cel,ter:BASE.ter,tel:BASE.tel};
    th.forEach(function(m){ if(m.tier===0)c.cel++; else if(m.tier===1)c.ter++; else c.tel++; });
    c.cel+=co.length;            // the core 15 are celestial
    return c;
  }
  function pad(n){return ("00"+n).slice(-3);}
  var el=document.createElement('div'); el.id='score'; document.body.appendChild(el);
  function render(){var c=counts();
    el.innerHTML=
      '<div class="sl"><b>'+pad(c.cel)+'</b> Celestial <span class="sd" style="background:#e9c987"></span></div>'+
      '<div class="sl"><b>'+pad(c.ter)+'</b> Terrestrial <span class="sd" style="background:#e98fce"></span></div>'+
      '<div class="sl"><b>'+pad(c.tel)+'</b> Telestial <span class="sd" style="background:#7fc8ff"></span></div>';
  }
  render(); addEventListener('storage',render); setInterval(render,4000);
})();

/* pause the hero galaxy when it scrolls off-screen */
(function(){
  var hb=document.querySelector('iframe.hero-bg');
  if(!hb || !('IntersectionObserver' in window)) return;
  new IntersectionObserver(function(es){es.forEach(function(e){
    try{e.target.contentWindow.postMessage(e.isIntersecting?'kolob:play':'kolob:pause','*');}catch(_){}
  });},{threshold:0.01}).observe(hb);
})();
