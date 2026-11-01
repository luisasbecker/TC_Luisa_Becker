#!/usr/bin/env python3
"""Render SVG verification previews using the installed Inkscape libraries.

This loads the native librsvg/Cairo renderer, without UI automation or downloads.
PNG previews are not editable Figma deliverables; source SVGs are retained.
"""
import ctypes as C
import base64
import json
import tempfile
from pathlib import Path
from xml.etree import ElementTree as ET

HERE=Path(__file__).resolve().parent
LIB=Path('/Applications/Inkscape.app/Contents/Resources/lib')
def function(lib,name,result,args):
    f=getattr(lib,name);f.restype=result;f.argtypes=args;return f

def render(source,dest):
    cairo=C.CDLL(str(LIB/'libcairo.2.dylib'))
    rsvg=C.CDLL(str(LIB/'librsvg-2.2.dylib'))
    gobject=C.CDLL(str(LIB/'libgobject-2.0.0.dylib'))
    fc=C.CDLL(str(LIB/'libfontconfig.1.dylib'))
    font=HERE.parents[1]/'mobile/assets/fonts/Inter-Variable.ttf'
    if font.exists():
        config=function(fc,'FcConfigGetCurrent',C.c_void_p,[])()
        function(fc,'FcConfigAppFontAddFile',C.c_int,[C.c_void_p,C.c_char_p])(config,str(font).encode())
    data=source.read_bytes();root=ET.fromstring(data)
    width,height=int(root.attrib['width']),int(root.attrib['height'])
    error=C.c_void_p()
    handle=function(rsvg,'rsvg_handle_new_from_data',C.c_void_p,[C.c_char_p,C.c_size_t,C.POINTER(C.c_void_p)])(data,len(data),C.byref(error))
    if not handle:raise RuntimeError(f'Invalid SVG: {source}')
    surface=function(cairo,'cairo_image_surface_create',C.c_void_p,[C.c_int,C.c_int,C.c_int])(0,width,height)
    context=function(cairo,'cairo_create',C.c_void_p,[C.c_void_p])(surface)
    ok=function(rsvg,'rsvg_handle_render_cairo',C.c_int,[C.c_void_p,C.c_void_p])(handle,context)
    dest.parent.mkdir(parents=True,exist_ok=True)
    status=function(cairo,'cairo_surface_write_to_png',C.c_int,[C.c_void_p,C.c_char_p])(surface,str(dest).encode())
    function(cairo,'cairo_destroy',None,[C.c_void_p])(context)
    function(cairo,'cairo_surface_destroy',None,[C.c_void_p])(surface)
    function(gobject,'g_object_unref',None,[C.c_void_p])(handle)
    if not ok or status:raise RuntimeError(f'Render failed: {source}, {status}')
    return {'source':str(source.relative_to(HERE)),'preview':str(dest.relative_to(HERE)),'width':width,'height':height}

def overview_sheets():
    from build_mockups import SCREEN_NAMES
    results=[]
    with tempfile.TemporaryDirectory(prefix='render-work-',dir=HERE/'previews') as temp:
        for theme in ['light','dark']:
            files=list(SCREEN_NAMES)
            for offset in range(0,len(files),6):
                pieces=[]
                for n,key in enumerate(files[offset:offset+6]):
                    x=(n%3)*390;y=(n//3)*880
                    png=Path(temp)/(theme+'-'+key+'.png')
                    render(HERE/'svg'/theme/(key+'.svg'),png)
                    data=base64.b64encode(png.read_bytes()).decode()
                    pieces.append(f'<image x="{x}" y="{y}" width="390" height="844" href="data:image/png;base64,{data}"/><text x="{x+24}" y="{y+866}" font-family="Inter" font-size="13" fill="#665957">{key}</text>')
                file=HERE/'previews'/f'overview-{theme}-{offset//6+1}.svg'
                file.write_text('<svg xmlns="http://www.w3.org/2000/svg" width="1170" height="1760" viewBox="0 0 1170 1760"><rect width="1170" height="1760" fill="#F1EFF0"/>'+''.join(pieces)+'</svg>')
                result=render(file,file.with_suffix('.png'))
                result['source']='svg/'+theme+'/'
                result['kind']='raster_contact_sheet_for_visual_review_only'
                results.append(result)
                file.unlink()
    return results

if __name__=='__main__':
    results=[]
    for theme in ['light','dark']:
        for name in ['00-foundations','00-components','00-user-flows','01-home','07-crop','13-classification','18-uncertainty','19-questionnaire','23-medium','25-unconfirmed','29-library']:
            results.append(render(HERE/'svg'/theme/(name+'.svg'),HERE/'previews'/(theme+'-'+name+'.png')))
    results.extend(overview_sheets())
    (HERE/'previews/render_manifest.json').write_text(json.dumps(results,indent=2)+'\n')
    print(f'Rendered {len(results)} SVG previews using native librsvg/Cairo.')
