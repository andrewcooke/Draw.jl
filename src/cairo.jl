
import Base.==

# at some point these should be a pull request for Cairo.jl
# WARNING: verbs have been moved to the front of function names

# this is a #define - no idea how to extract it dynamically
# https://developer.gnome.org/pango/stable/pango-Glyph-Storage.html#PANGO-SCALE:CAPS
const PANGO_SCALE = 1024

function has_current_point(ctx::X.CairoContext)
    ccall((:cairo_has_current_point, X._jl_libcairo), Int, (Ptr{Void},), ctx.ptr) != 0
end

# can be called if has_current_point is false (will return 0.0, 0.0)
function get_current_point(ctx::X.CairoContext)
    x = Cdouble[0]
    y = Cdouble[0]
    ccall((:cairo_get_current_point, X._jl_libcairo), Void, (Ptr{Void}, Ptr{Cdouble}, Ptr{Cdouble}), ctx.ptr, x, y)
    (x[1], y[1])
end

immutable FontMap
    ptr::Ptr{Void}
end

function get_font_map_default()
    FontMap(ccall((:pango_cairo_font_map_get_default, X._jl_libpangocairo), Ptr{Void}, ()))
end

immutable FontFamily
    ptr::Ptr{Void}
end

# this assumes the underlying structs that are pointed to are
# persistent which seems to be implied by the api.  so we copy the
# array of pointers (maybe that could be avoied by calling
# pointer_to_array with true)
function list_families(fm::FontMap)
    pff = Ptr{Ptr{Void}}[0]
    pn = Cint[0]
    ccall((:pango_font_map_list_families, X._jl_libpango), Void, (Ptr{Void}, Ptr{Ptr{Ptr{Void}}}, Ptr{Cint}), fm.ptr, pff, pn)
    a = pointer_to_array(pff[1], (pn[1],), false)
    ff = [FontFamily(p) for p in a]
    Libc.free(pff[1])
    ff
end

function get_name(ff::FontFamily)
    bytestring(ccall((:pango_font_family_get_name, X._jl_libpango), Cstring, (Ptr{Void},), ff.ptr))
end

function is_monospace(ff::FontFamily)
    convert(Bool, ccall((:pango_font_family_is_monospace, X._jl_libpango), Cint, (Ptr{Void},), ff.ptr))
end

immutable FontFace
    ptr::Ptr{Void}
end

# this assumes the underlying structs that are pointed to are
# persistent which seems to be implied by the api.  so we copy the
# array of pointers (maybe that could be avoied by calling
# pointer_to_array with true)
function list_faces(ff::FontFamily)
    pfc = Ptr{Ptr{Void}}[0]
    pn = Cint[0]
    ccall((:pango_font_family_list_faces, X._jl_libpango), Void, (Ptr{Void}, Ptr{Ptr{Ptr{Void}}}, Ptr{Cint}), ff.ptr, pfc, pn)
    a = pointer_to_array(pfc[1], (pn[1],), false)
    fc = [FontFace(p) for p in a]
    Libc.free(pfc[1])
    fc
end

function get_name(fc::FontFace)
    bytestring(ccall((:pango_font_face_get_face_name, X._jl_libpango), Cstring, (Ptr{Void},), fc.ptr))
end

# cannot use immutable here as finalizer() complains
type FontDescription
    ptr::Ptr{Void}
    function FontDescription(ptr)
        this = new(ptr)
        finalizer(this, fd -> ccall((:pango_font_description_free, X._jl_libpango), Void, (Ptr{Void},), fd.ptr))
        this
    end
end

function describe(fc::FontFace)
    FontDescription(ccall((:pango_font_face_describe, X._jl_libpango), Ptr{Void}, (Ptr{Void},), fc.ptr))
end

# non-standard function names here to support round-tripping to strings

function Base.show(io::IO, fd::FontDescription)
    s = bytestring(ccall((:pango_font_description_to_string, X._jl_libpango), Cstring, (Ptr{Void},), fd.ptr))
    print(io, s)
end

function Base.convert(::Type{FontDescription}, s::AbstractString)
    FontDescription(ccall((:pango_font_description_from_string, X._jl_libpango), Ptr{Void}, (Ptr{Cchar},), s))
end

function ==(fd1::FontDescription, fd2::FontDescription)
    convert(Bool, ccall((:pango_font_description_equal, X._jl_libpango), Cint, (Ptr{Void}, Ptr{Void}), fd1.ptr, fd2.ptr))
end

function Base.hash(fd::FontDescription)
    ccall((:pango_font_description_hash, X._jl_libpango), Culong, (Ptr{Void},), fd.ptr)
end

function Base.copy(fd::FontDescription)
    FontDescription(ccall((:pango_font_description_copy, X._jl_libpango), Ptr{Void}, (Ptr{Void},), fd.ptr))
end

for name in [:style, :variant, :weight, :stretch, :gravity]
    g1 = symbol(:get_, name)
    g2 = symbol(:pango_font_description_, g1)
    s1 = symbol(:set_, name)
    s2 = symbol(:pango_font_description_, g1)
    @eval begin
        $g1(fd::FontDescription) = ccall(($(Expr(:quote, g2)), X._jl_libpango), Culong, (Ptr{Void},), fd.ptr)
        $s1(fd::FontDescription, x) = ccall(($(Expr(:quote, s2)), X._jl_libpango), Void, (Ptr{Void}, Culong), fd.ptr, x)
    end
end
