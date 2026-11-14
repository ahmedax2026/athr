// No secrets in source. FIREBASE_SERVICE_ACCOUNT is a Cloudflare Secret.
const json = (body, status=200) => Response.json(body, {status, headers:{"Cache-Control":"no-store"}});
const enc = new TextEncoder();
const b64 = bytes => btoa(String.fromCharCode(...bytes)).replace(/\+/g,"-").replace(/\//g,"_").replace(/=+$/,"");
let cached;
async function accessToken(account) {
  if(cached && cached.exp > Date.now()+60000) return cached.token;
  const now=Math.floor(Date.now()/1000);
  const encode=x=>b64(enc.encode(JSON.stringify(x)));
  const unsigned=encode({alg:"RS256",typ:"JWT"})+"."+encode({
    iss:account.client_email, scope:"https://www.googleapis.com/auth/firebase.messaging https://www.googleapis.com/auth/datastore",
    aud:"https://oauth2.googleapis.com/token",iat:now,exp:now+3600});
  const pem=account.private_key.replace(/-----[^-]+-----/g,"").replace(/\s/g,"");
  const key=await crypto.subtle.importKey("pkcs8",Uint8Array.from(atob(pem),c=>c.charCodeAt(0)),{name:"RSASSA-PKCS1-v1_5",hash:"SHA-256"},false,["sign"]);
  const signature=await crypto.subtle.sign("RSASSA-PKCS1-v1_5",key,enc.encode(unsigned));
  const r=await fetch("https://oauth2.googleapis.com/token",{method:"POST",body:new URLSearchParams({grant_type:"urn:ietf:params:oauth:grant-type:jwt-bearer",assertion:unsigned+"."+b64(new Uint8Array(signature))})});
  if(!r.ok) throw Error("oauth");
  const data=await r.json(); cached={token:data.access_token,exp:Date.now()+data.expires_in*1000};
  return cached.token;
}
const id = x => typeof x==="string" && /^[A-Za-z0-9_-]{1,128}$/.test(x);
export default {async fetch(req,env){
  const path=new URL(req.url).pathname;
  if(req.method==="GET"&&path==="/") return json({service:"Athr Notifications",status:"online",version:2,firebaseConfigured:!!env.FIREBASE_SERVICE_ACCOUNT});
  if(req.method!=="POST"||path!=="/remind") return json({error:"not_found"},404);
  try {
    const authorization=req.headers.get("Authorization")||"";
    if(!/^Bearer [A-Za-z0-9._-]{20,8192}$/.test(authorization)) return json({error:"auth_required"},401);
    if(Number(req.headers.get("Content-Length")||0)>4096) return json({error:"too_large"},413);
    const raw=await req.text(); if(raw.length>4096)return json({error:"too_large"},413);
    let body; try{body=JSON.parse(raw);}catch{return json({error:"invalid_json"},400);}
    const {roomId,recipientId,senderId}=body||{};
    if(![roomId,recipientId,senderId].every(id)||recipientId===senderId)return json({error:"invalid_ids"},400);
    const account=JSON.parse(env.FIREBASE_SERVICE_ACCOUNT);
    const root="projects/"+account.project_id+"/databases/(default)";
    const api="https://firestore.googleapis.com/v1/"+root;
    const headers={Authorization:authorization,"Content-Type":"application/json"};
    // The user's Firebase ID token is verified by Firestore, not by trusting the JSON.
    const room=await fetch(api+"/documents/khatmas/"+roomId,{headers});
    if(!room.ok)return json({error:"room_access"},403);
    const fields=(await room.json()).fields||{};
    if(fields.creatorId?.stringValue!==senderId || fields.started?.booleanValue!==true || fields.closed?.booleanValue===true)
      return json({error:"room_not_eligible"},403);
    // Only the trusted server can read a device registration. No client can read another user's token.
    const token=await accessToken(account);
    const device=await fetch(api+"/documents/push_devices/"+recipientId,{headers:{Authorization:"Bearer "+token}});
    if(device.status===404)return json({error:"device_not_registered"},409);
    if(!device.ok)return json({error:"device_access"},502);
    const registration=(await device.json()).fields?.token?.stringValue;
    if(typeof registration!=="string"||!registration)return json({error:"device_not_registered"},409);
    // Rules enforce owner identity, pending parts, membership, and a 12-hour cooldown atomically.
    const commit=await fetch(api+"/documents:commit",{method:"POST",headers,body:JSON.stringify({writes:[{
      update:{name:root+"/documents/khatmas/"+roomId+"/reminders/"+recipientId,fields:{senderId:{stringValue:senderId}}},
      updateTransforms:[{fieldPath:"sentAt",setToServerValue:"REQUEST_TIME"}]
    }]})});
    if(!commit.ok)return json({error:"not_allowed_or_cooldown"},403);
    const push=await fetch("https://fcm.googleapis.com/v1/projects/"+account.project_id+"/messages:send",{method:"POST",headers:{Authorization:"Bearer "+token,"Content-Type":"application/json"},body:JSON.stringify({message:{
      token:registration,notification:{title:"أثر لا ينقطع • تذكير بالختمة",body:"لا تنسَ إكمال وردك من القرآن الكريم. تقبل الله منك."},
      data:{type:"khatma_reminder",roomId,recipientId},android:{priority:"HIGH",ttl:"43200s"}
    }})});
    return push.ok?json({sent:true}):json({sent:false,recorded:true,error:"fcm_failed"},502);
  } catch {return json({error:"service_error"},500);}
}};
