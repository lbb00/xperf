"use strict";
const fs = require("fs");
const path = require("path");
const { Writable } = require("stream");
const ROUNDS = 9, WARM = 3;
const N = Number(process.env.AT_N || 2e5);
const N_CONSOLE = Number(process.env.AT_CONSOLE_N || 2e4);
const OUT = process.env.EVIDENCE_DIR || path.join(__dirname, "..", "..", "evidence");
function median(xs){const a=xs.slice().sort((p,q)=>p-q);const m=Math.floor(a.length/2);return a.length%2?a[m]:(a[m-1]+a[m])/2;}
function timeMany(fn){for(let i=0;i<WARM;i++)fn();const s=[];let sink=0;for(let r=0;r<ROUNDS;r++){const t0=process.hrtime.bigint();sink=(sink+(fn()|0))|0;const t1=process.hrtime.bigint();s.push(Number(t1-t0)/1e6);}return median(s);}
function emit(rule, pairs){let lastAfter=1;const ts=new Date().toISOString();const lines=pairs.map(p=>{if(p.role==="after")lastAfter=p.median_ms;const ratio=p.median_ms/lastAfter;console.log(" ",p.role,p.case,p.median_ms,ratio);return JSON.stringify({rule,case:p.case,role:p.role,runtime:"node-proxy",note:"Not ArkTS VM",node:process.version,v8:process.versions.v8,median_ms:p.median_ms,ops:p.ops,ratio,ts});});fs.writeFileSync(path.join(OUT,rule+".jsonl"),lines.join("\n")+"\n");console.log("wrote",rule);}
// at-alloc-hot new in loop vs reuse
emit("at-alloc-hot",[
  {case:"reuse_buffer",role:"after",median_ms:timeMany(()=>{const buf=new Uint8Array(16);let s=0;for(let i=0;i<N;i++){buf[0]=i&255;s=(s+buf[0])|0;}return s;}),ops:N},
  {case:"new_in_loop",role:"before",median_ms:timeMany(()=>{let s=0;for(let i=0;i<N;i++){const buf=new Uint8Array(16);buf[0]=i&255;s=(s+buf[0])|0;}return s;}),ops:N},
]);
// at-object-delete delete vs assign undefined / Map
emit("at-object-delete",[
  {case:"map_delete_free",role:"after",median_ms:timeMany(()=>{const m=new Map();for(let i=0;i<N;i++)m.set(i&1023,i);let s=0;for(let i=0;i<1024;i++){m.delete(i);s++;}return s;}),ops:1024},
  {case:"object_delete",role:"before",median_ms:timeMany(()=>{const o=Object.create(null);for(let i=0;i<N;i++)o[i&1023]=i;let s=0;for(let i=0;i<1024;i++){delete o[i];s++;}return s;}),ops:1024},
]);
function withDiscard(fn){const d=new Writable({write(_c,_e,cb){cb();}});const ow=process.stdout.write;process.stdout.write=function(c,e,cb){return d.write(c,e,cb);};try{return fn();}finally{process.stdout.write=ow;}}
emit("at-console-hot",[
  {case:"quiet_then_once",role:"after",median_ms:timeMany(()=>withDiscard(()=>{let s=0;for(let i=0;i<N_CONSOLE;i++)s=(s+i)|0;console.log(s);return s;})),ops:N_CONSOLE},
  {case:"console_in_loop",role:"before",median_ms:timeMany(()=>withDiscard(()=>{let s=0;for(let i=0;i<N_CONSOLE;i++){console.log(i);s=(s+i)|0;}return s;})),ops:N_CONSOLE},
]);
