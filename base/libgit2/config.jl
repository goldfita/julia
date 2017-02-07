# This file is a part of Julia. License is MIT: http://julialang.org/license

function GitConfig(path::AbstractString,
                   level::Consts.GIT_CONFIG = Consts.CONFIG_LEVEL_APP,
                   force::Bool=false)
    # create new config object
    cfg_ptr_ptr = Ref{Ptr{Void}}(C_NULL)
    @check ccall((:git_config_new, :libgit2), Cint, (Ptr{Ptr{Void}},), cfg_ptr_ptr)
    cfg = GitConfig(cfg_ptr_ptr[])
    try
        addfile(cfg, path, level, force)
    catch ex
        close(cfg)
        rethrow(ex)
    end
    return cfg
end

function GitConfig(repo::GitRepo)
    cfg_ptr_ptr = Ref{Ptr{Void}}(C_NULL)
    @check ccall((:git_repository_config, :libgit2), Cint,
                  (Ptr{Ptr{Void}}, Ptr{Void}), cfg_ptr_ptr, repo.ptr)
    return GitConfig(repo, cfg_ptr_ptr[])
end

function GitConfig(level::Consts.GIT_CONFIG = Consts.CONFIG_LEVEL_DEFAULT)
    cfg_ptr_ptr = Ref{Ptr{Void}}(C_NULL)
    @check ccall((:git_config_open_default, :libgit2), Cint,
                  (Ptr{Ptr{Void}}, ), cfg_ptr_ptr)
    cfg = GitConfig(cfg_ptr_ptr[])
    if level != Consts.CONFIG_LEVEL_DEFAULT
        glb_cfg_ptr_ptr = Ref{Ptr{Void}}(C_NULL)
        tmpcfg = cfg
        try
            @check ccall((:git_config_open_level, :libgit2), Cint,
                         (Ptr{Ptr{Void}}, Ptr{Void}, Cint),
                          glb_cfg_ptr_ptr, cfg.ptr, Cint(level))
            cfg = GitConfig(glb_cfg_ptr_ptr[])
        finally
            close(tmpcfg)
        end
    end
    return cfg
end

function addfile(cfg::GitConfig, path::AbstractString,
                 level::Consts.GIT_CONFIG = Consts.CONFIG_LEVEL_APP,
                 force::Bool=false)
    @check ccall((:git_config_add_file_ondisk, :libgit2), Cint,
                  (Ptr{Ptr{Void}}, Cstring, Cint, Cint),
                   cfg.ptr, path, Cint(level), Cint(force))
end

function get(::Type{<:AbstractString}, c::GitConfig, name::AbstractString)
    buf_ref = Ref(Buffer())
    @check ccall((:git_config_get_string_buf, :libgit2), Cint,
                 (Ptr{Buffer}, Ptr{Void}, Cstring), buf_ref, c.ptr, name)
    buf = buf_ref[]
    str = unsafe_string(buf.ptr, buf.size)
    free(buf_ref)
    str
end

function get(::Type{Bool}, c::GitConfig, name::AbstractString)
    val_ptr = Ref(Cint(0))
    @check ccall((:git_config_get_bool, :libgit2), Cint,
          (Ptr{Cint}, Ptr{Void}, Cstring), val_ptr, c.ptr, name)
    return Bool(val_ptr[])
end

function get(::Type{Int32}, c::GitConfig, name::AbstractString)
    val_ptr = Ref(Cint(0))
    @check ccall((:git_config_get_int32, :libgit2), Cint,
          (Ptr{Cint}, Ptr{Void}, Cstring), val_ptr, c.ptr, name)
    return val_ptr[]
end

function get(::Type{Int64}, c::GitConfig, name::AbstractString)
    val_ptr = Ref(Cintmax_t(0))
    @check ccall((:git_config_get_int64, :libgit2), Cint,
          (Ptr{Cintmax_t}, Ptr{Void}, Cstring), val_ptr, c.ptr, name)
    return val_ptr[]
end

function get{T}(c::GitConfig, name::AbstractString, default::T)
    res = default
    try res = get(T,c,name) end
    return res
end

function getconfig(r::GitRepo, name::AbstractString, default)
    with(GitConfig, r) do cfg
        get(cfg, name, default)
    end
end

function getconfig(rname::AbstractString, name::AbstractString, default)
    with(GitRepo, rname) do r
        with(GitConfig, r) do cfg
            get(cfg, name, default)
        end
    end
end

function getconfig(name::AbstractString, default)
    with(GitConfig) do cfg
        get(cfg, name, default)
    end
end

function set!(c::GitConfig, name::AbstractString, value::AbstractString)
    @check ccall((:git_config_set_string, :libgit2), Cint,
                  (Ptr{Void}, Cstring, Cstring), c.ptr, name, value)
end

function set!(c::GitConfig, name::AbstractString, value::Bool)
    bval = Int32(value)
    @check ccall((:git_config_set_bool, :libgit2), Cint,
                  (Ptr{Void}, Cstring, Cint), c.ptr, name, bval)
end

function set!(c::GitConfig, name::AbstractString, value::Int32)
    @check ccall((:git_config_set_int32, :libgit2), Cint,
                  (Ptr{Void}, Cstring, Cint), c.ptr, name, value)
end

function set!(c::GitConfig, name::AbstractString, value::Int64)
    @check ccall((:git_config_set_int64, :libgit2), Cint,
                  (Ptr{Void}, Cstring, Cintmax_t), c.ptr, name, value)
end

function GitConfigIter(cfg::GitConfig)
    ci_ptr = Ref{Ptr{Void}}(C_NULL)
    @check ccall((:git_config_iterator_new, :libgit2), Cint,
                  (Ptr{Ptr{Void}}, Ptr{Void}), ci_ptr, cfg.ptr)
    return GitConfigIter(ci_ptr[])
end

function GitConfigIter(cfg::GitConfig, name::AbstractString)
    ci_ptr = Ref{Ptr{Void}}(C_NULL)
    @check ccall((:git_config_multivar_iterator_new, :libgit2), Cint,
                  (Ptr{Ptr{Void}}, Ptr{Void}, Cstring, Cstring),
                  ci_ptr, cfg.ptr, name, C_NULL)
    return GitConfigIter(ci_ptr[])
end

function GitConfigIter(cfg::GitConfig, name::AbstractString, value::Regex)
    ci_ptr = Ref{Ptr{Void}}(C_NULL)
    @check ccall((:git_config_multivar_iterator_new, :libgit2), Cint,
                  (Ptr{Ptr{Void}}, Ptr{Void}, Cstring, Cstring),
                  ci_ptr, cfg.ptr, name, value.pattern)
    return GitConfigIter(ci_ptr[])
end

function GitConfigIter(cfg::GitConfig, name::Regex)
    ci_ptr = Ref{Ptr{Void}}(C_NULL)
    @check ccall((:git_config_iterator_glob_new, :libgit2), Cint,
                  (Ptr{Ptr{Void}}, Ptr{Void}, Cstring),
                  ci_ptr, cfg.ptr, name.pattern)
    return GitConfigIter(ci_ptr[])
end

function Base.start(ci::GitConfigIter)
    entry_ptr_ptr = Ref{Ptr{ConfigEntry}}(C_NULL)
    err = ccall((:git_config_next, :libgit2), Cint,
                 (Ptr{Ptr{ConfigEntry}}, Ptr{Void}), entry_ptr_ptr, ci.ptr)
    if err == Int(Error.GIT_OK)
        unsafe_load(entry_ptr_ptr[])
    else
        nothing
    end
end

Base.done(ci::GitConfigIter, state) = state === nothing

function Base.next(ci::GitConfigIter, state)
    entry = state
    entry_ptr_ptr = Ref{Ptr{ConfigEntry}}(C_NULL)
    err = ccall((:git_config_next, :libgit2), Cint,
                 (Ptr{Ptr{ConfigEntry}}, Ptr{Void}), entry_ptr_ptr, ci.ptr)
    if err == Int(Error.GIT_OK)
        (entry, unsafe_load(entry_ptr_ptr[]))
    else
        (entry, nothing)
    end
end

Base.iteratorsize(::Type{GitConfigIter}) = Base.SizeUnknown()
