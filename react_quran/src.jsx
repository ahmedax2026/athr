import React, {useEffect, useState} from 'react';
import {createRoot} from 'react-dom/client';
import {ReadingView} from 'react-quran';
import 'react-quran/fonts/index.css';
import './style.css';
function App(){
 const [page,setPage]=useState(()=>Math.max(1,Math.min(604,Number(new URLSearchParams(location.search).get('page'))||1)));
 const [dark,setDark]=useState(false);
 useEffect(()=>{const handler=e=>{if(e.key==='ArrowLeft')setPage(p=>Math.min(604,p+1));if(e.key==='ArrowRight')setPage(p=>Math.max(1,p-1));};window.addEventListener('keydown',handler);return()=>window.removeEventListener('keydown',handler)},[]);
 useEffect(()=>{
   document.title='المصحف • صفحة '+page;
   const words=document.querySelector('.reader')?.textContent?.trim()||'';
   const report=()=>window.ReactQuranBridge?.postMessage(JSON.stringify({type:'ready',page,characters:words.length}));
   if(words.length>30)report();else window.ReactQuranBridge?.postMessage(JSON.stringify({type:'error',message:'صفحة المصحف لا تحتوي على نص قرآني'}));
 },[page]);
 useEffect(()=>{window.setQuranPage=n=>setPage(Math.max(1,Math.min(604,Number(n)||1)));},[]);
 return <main className={dark?'dark':''}>
  <header><button onClick={()=>setDark(v=>!v)} aria-label="تغيير المظهر">◐</button><strong>المصحف • صفحة {page}</strong><span>حفص</span></header>
  <section className="reader"><ReadingView page={page} readingViewStyles={{width:'100%',maxWidth:'100%',backgroundColor:dark?'#19382f':'#fff9ec'}} surahTitleStyles={{color:dark?'#f7e8c4':'#173c32'}} fixedAspectRatio={true}/></section>
  <footer><button onClick={()=>setPage(p=>Math.max(1,p-1))} disabled={page===1}>السابقة</button><label>صفحة {page} من 604</label><button onClick={()=>setPage(p=>Math.min(604,p+1))} disabled={page===604}>التالية</button></footer>
 </main>
}
window.addEventListener('error',event=>{
 window.ReactQuranBridge?.postMessage(JSON.stringify({type:'error',message:event.message||'JavaScript error'}));
});
class ReaderErrorBoundary extends React.Component{
 constructor(props){super(props);this.state={error:null}}
 static getDerivedStateFromError(error){return {error}}
 componentDidCatch(error){window.ReactQuranBridge?.postMessage(JSON.stringify({type:'error',message:String(error)}))}
 render(){return this.state.error?<p style={{padding:24,color:'#9a2828',textAlign:'center'}}>حدث خطأ في عرض المصحف: {String(this.state.error)}</p>:this.props.children}
}
createRoot(document.getElementById('root')).render(<ReaderErrorBoundary><App/></ReaderErrorBoundary>);
