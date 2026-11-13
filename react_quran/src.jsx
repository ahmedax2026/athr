import React, {useEffect, useRef, useState} from 'react';
import {createRoot} from 'react-dom/client';
import {ReadingView} from 'react-quran';
import 'react-quran/fonts/index.css';
import './style.css';

const limit = (n, lo, hi) => Math.min(hi, Math.max(lo, Math.round(Number(n) || lo)));
const notify = data => window.ReactQuranBridge?.postMessage(JSON.stringify(data));

function App() {
  const [page, setPage] = useState(1);
  const [zoom, setZoom] = useState(1);
  const [bounds, setBounds] = useState({first:1, last:604});
  const boundsRef = useRef({first:1, last:604});
  const touch = useRef(null);
  const zoomRef = useRef(1);
  const readyRef = useRef(false);

  const go = (target, fromGesture = false) => {
    const {first,last} = boundsRef.current;
    const requested = Math.round(Number(target) || first);
    const clamped = limit(requested, first, last);
    if (fromGesture && requested > last) notify({type:'partEnd', page:last});
    setPage(clamped);
  };

  useEffect(() => {
    window.setQuranBounds = (first, last) => {
      const a = limit(first,1,604), b = limit(last,a,604);
      boundsRef.current = {first:a,last:b};
      setBounds({first:a,last:b});
      setPage(p=>limit(p,a,b));
    };
    window.setQuranPage = p => go(p);
    window.setQuranZoom = z => {
      zoomRef.current = Math.min(2.8, Math.max(0.8, Number(z)||1));
      setZoom(zoomRef.current);
    };
    window.getQuranPage = () => page;
    const keys = e => {
      if(e.key==='ArrowRight') go(page+1,true);
      if(e.key==='ArrowLeft') go(page-1,true);
    };
    window.addEventListener('keydown',keys);
    return () => window.removeEventListener('keydown',keys);
  }, [page]);

  useEffect(() => {
    document.title = 'المصحف • صفحة ' + page;
    notify({type:'page',page});
    const wordCount = document.querySelector('.reader')?.textContent?.trim().length || 0;
    if (wordCount > 30) {
      if (!readyRef.current) {readyRef.current=true; notify({type:'ready',page});}
    } else {
      // The Quran component can render asynchronously: do not misreport initial load.
      const retry = setTimeout(() => {
        const length = document.querySelector('.reader')?.textContent?.trim().length || 0;
        if (length > 30 && !readyRef.current) {
          readyRef.current=true; notify({type:'ready',page});
        }
      },500);
      return () => clearTimeout(retry);
    }
  },[page]);

  function startTouch(e) {
    if(e.touches.length===2) {
      touch.current = {pinch:Math.hypot(e.touches[0].clientX-e.touches[1].clientX,
        e.touches[0].clientY-e.touches[1].clientY), zoom:zoomRef.current};
    } else if(e.touches.length===1) {
      touch.current={x:e.touches[0].clientX,y:e.touches[0].clientY};
    } else touch.current=null;
  }
  function moveTouch(e) {
    const t=touch.current;
    if(!t?.pinch || e.touches.length!==2)return;
    const d=Math.hypot(e.touches[0].clientX-e.touches[1].clientX,
      e.touches[0].clientY-e.touches[1].clientY);
    const z=Math.max(0.8,Math.min(2.8,t.zoom*d/t.pinch));
    zoomRef.current=z;setZoom(z);
  }
  function endTouch(e) {
    const t=touch.current;
    touch.current=null;
    if (!t || t.pinch || e.changedTouches.length!==1)return;
    const dx=e.changedTouches[0].clientX-t.x;
    const dy=e.changedTouches[0].clientY-t.y;
    if(Math.abs(dx)<55 || Math.abs(dx)<Math.abs(dy)*1.3)return;
    // RTL Quran: swipe right to advance, swipe left to return.
    go(page+(dx>0?1:-1),true);
  }

  return <main>
    <section className="reader" onTouchStart={startTouch}
      onTouchMove={moveTouch} onTouchEnd={endTouch} onTouchCancel={()=>touch.current=null}>
      <div className="page-surface" style={{zoom:zoom}}>
        <ReadingView page={page} readingViewStyles={{
          width:'100%',maxWidth:'100%',backgroundColor:'#fff9ec'}}
          surahTitleStyles={{color:'#173c32'}} fixedAspectRatio={true}/>
      </div>
    </section>
    {bounds.last<604 && page===bounds.last &&
      <div className="end-hint" role="status">وصلت لنهاية الجزء. اضغط «أتممت قراءة الجزء» بالأسفل.</div>}
  </main>;
}
window.addEventListener('error', event =>
  notify({type:'error',message:event.message||'JavaScript error'}));
class ReaderErrorBoundary extends React.Component {
  constructor(props){super(props);this.state={error:null}}
  static getDerivedStateFromError(error){return {error}}
  componentDidCatch(error){notify({type:'error',message:String(error)})}
  render(){return this.state.error
    ? <p style={{padding:24,color:'#9a2828',textAlign:'center'}}>حدث خطأ في عرض المصحف: {String(this.state.error)}</p>
    : this.props.children}
}
createRoot(document.getElementById('root')).render(<ReaderErrorBoundary><App/></ReaderErrorBoundary>);
