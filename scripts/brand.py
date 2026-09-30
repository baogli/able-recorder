#!/usr/bin/env python3
"""Author native editable brand layers. Run with Tesseract CLI 0.3.0 installed."""
import json, pathlib, subprocess, os
ROOT = pathlib.Path(__file__).resolve().parents[1]
CLI = os.environ.get('TSRCT', str(ROOT / '.tools/tesseract/bin/tsrct'))
OUT = ROOT / 'marketing/designs'
WORK = OUT / '.tesseract-work'
BG='#0C121B'; PANEL='#172330'; MINT='#A4F4D2'; WHITE='#F3F6F5'; MUTED='#9CABB8'; CORAL='#FF785F'
def rgba(h): return [int(h[i:i+2],16)/255 for i in (1,3,5)]+[1]
class Canvas:
 def __init__(self,w,h): self.w=w;self.h=h;self.layers=[]
 def base(self,name,x,y):
  return {'id':len(self.layers)+1,'name':name,'blendMode':'normal','activeRange':{'start':0,'duration':3000},'transform':{'position':[x,y],'anchorPoint':[0,0],'scale':[100,100],'rotation':0,'opacity':100}}
 def rect(self,name,x,y,w,h,c,r=0):
  z=self.base(name,x,y);z.update(type='Rect',rect={'size':[w,h],'fillColor':rgba(c),'roundness':r});self.layers.append(z)
 def text(self,name,s,x,y,size=28,c=WHITE,style='Regular'):
  z=self.base(name,x,y);z.update(type='Text',sourceText={'text':s,'fontFamily':'Inter','fontStyle':style,'fontSize':size,'fillColor':rgba(c),'strokeWidth':0,'justification':'left'});self.layers.append(z)
 def mark(self,x,y,size):
  k=size/256
  self.rect('Screen outline',x,y+32*k,256*k,180*k,MINT,30*k)
  self.rect('Screen inset',x+12*k,y+44*k,232*k,156*k,BG,20*k)
  for i,(height,offset) in enumerate([(54,84),(112,55),(78,72)]):self.rect('Audio waveform '+str(i),x+(57+i*48)*k,y+offset*k,22*k,height*k,MINT,11*k)
  self.rect('Record badge rim',x+177*k,y+148*k,78*k,78*k,BG,39*k)
  self.rect('Record indicator',x+189*k,y+160*k,54*k,54*k,CORAL,27*k)
 def save(self,name):
  project=OUT/(name+'.tsrct');layout=WORK/(name+'.json')
  if not project.exists():subprocess.run([CLI,'project','create','--project',str(project)],check=True)
  subprocess.run([CLI,'project','import-font','--project',str(project),'--file',str(ROOT/'marketing/fonts/Inter.ttf')],check=True,stdout=subprocess.DEVNULL)
  subprocess.run([CLI,'project','checkout','--project',str(project),'--output',str(layout)],check=True,stdout=subprocess.DEVNULL)
  d=json.loads(layout.read_text());d['dimensions']={'width':self.w,'height':self.h};d['backgroundColor']=rgba(BG);d['composition']['layers']=self.layers[::-1]
  layout.write_text(json.dumps(d,ensure_ascii=False,indent=2))
  subprocess.run([CLI,'project','commit','--project',str(project),'--file',str(layout)],check=True)
  subprocess.run([CLI,'preview','--project',str(project),'--time','1','--output',str(OUT/(name+'.png'))],check=True)

def header(c,x=64,y=64):
 c.mark(x,y-17,58);c.text('Brand','Able Recorder',x+82,y+30,32,WHITE,'SemiBold')
def footer(c,y):
 c.rect('Footer rule',64,y-36,c.w-128,1,'#30404D');c.text('Repository','github.com/baogli/able-recorder',64,y+8,24,MUTED);c.text('Platform','macOS 14+  /  Apple Silicon',64,y+44,20,MUTED)

def github():
 c=Canvas(1280,640);header(c)
 c.text('Headline 1','Capture your screen.',64,242,66,WHITE,'Bold');c.text('Headline 2','Keep your sound.',64,326,66,MINT,'Bold')
 c.text('Positioning','A free Mac recorder for musicians.',68,397,29)
 c.text('Value','Choose your inputs. Get an MP4.',68,444,27,MUTED)
 c.rect('Badge',68,493,274,46,PANEL,12);c.text('Badge copy','FREE + OPEN SOURCE',87,524,19,MINT,'SemiBold')
 c.mark(949,205,239)
 c.text('Footer','github.com/baogli/able-recorder',68,588,22,MUTED)
 c.save('GitHub-social')
def square(ru=False):
 c=Canvas(1080,1080);header(c)
 if ru:
  for i,s in enumerate(['Запиши экран.','Сохрани звук.']):c.text('Headline '+str(i),s,64,244+i*90,73,MINT if i else WHITE,'Bold')
  c.text('Positioning','Бесплатный Mac-рекордер для музыкантов.',67,414,29)
  a=['Выбери экран','Назначь входы L / R','Получи готовый MP4']
 else:
  for i,s in enumerate(['Your session.','Ready to share.']):c.text('Headline '+str(i),s,64,244+i*90,76,MINT if i else WHITE,'Bold')
  c.text('Positioning','A free Mac recorder for musicians.',67,414,30)
  a=['Choose your screen','Select your L / R inputs','Save a ready-to-share MP4']
 for i,s in enumerate(a):
  y=480+i*99;c.rect('Step '+str(i),64,y,952,78,PANEL,18);c.text('Step number '+str(i),'0'+str(i+1),90,y+49,27,MINT,'SemiBold');c.text('Step copy '+str(i),s,162,y+49,29)
 c.text('Features','H.264 / HEVC   ·   30 / 60 fps   ·   MIT license',67,865,25,MUTED)
 footer(c,961);c.save('Social-square-'+('RU' if ru else 'EN'))
def story():
 c=Canvas(1080,1920);header(c,80,140)
 for i,s in enumerate(['Музыка —','в звуке.','Процесс —','на экране.']):c.text('Headline '+str(i),s,80,372+i*109,90,MINT if i==1 else WHITE,'Bold')
 c.mark(368,835,344)
 c.text('Value','Выбери экран и аудиовходы.',80,1350,43)
 c.text('Value 2','Получи MP4 для публикации.',80,1416,43)
 c.rect('Free badge',80,1511,920,99,MINT,24);c.text('Free copy','БЕСПЛАТНО. ОТКРЫТЫЙ КОД.',117,1574,39,BG,'Bold')
 c.text('Repository','github.com/baogli/able-recorder',80,1732,31,MUTED)
 c.text('Platform','macOS 14+  /  Apple Silicon',80,1784,27,MUTED);c.save('Story-RU')
def icon():
 c=Canvas(1024,1024);c.mark(164,146,696);c.save('App-icon')
if __name__=='__main__':
 import sys
 choice=sys.argv[1:] or ['all']
 if 'github' in choice or 'all' in choice:github()
 if 'all' in choice:square();square(True);story();icon()
