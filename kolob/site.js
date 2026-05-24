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
