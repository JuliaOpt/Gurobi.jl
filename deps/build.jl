using Libdl

const DEPS_FILE = joinpath(@__DIR__, "deps.jl")

if isfile(DEPS_FILE)
    rm(DEPS_FILE)
end

function write_depsfile(path)
    if Sys.iswindows()
        # When `path` gets written out to a file, it will escape any
        # backslashes, so we need to doubly escape them. If your path uses
        # forward slashes, this operation won't do anything.
        path = replace(path, "\\" => "\\\\")
    end
    open(DEPS_FILE, "w") do io
        println(io, "const libgurobi = \"$(path)\"")
    end
end

const ALIASES = [
    "gurobi90",
]

paths_to_try = copy(ALIASES)

for a in ALIASES
    if haskey(ENV, "GUROBI_HOME")
        if Sys.isunix()
            push!(paths_to_try, joinpath(ENV["GUROBI_HOME"], "lib", string("lib", a, ".so")))
        end
        if Sys.iswindows()
            push!(paths_to_try, joinpath(ENV["GUROBI_HOME"], "bin", string(a, ".", Libdl.dlext)))
        end
        if Sys.isapple()
            push!(paths_to_try, joinpath(ENV["GUROBI_HOME"], "lib", string("lib", a, ".dylib")))
        end
    end
    # gurobi uses .so on OS X for some reason
    if Sys.isapple()
        push!(paths_to_try, string("lib$a.so"))
        push!(paths_to_try, string("lib$a.dylib"))
    end
end

found = false
for l in paths_to_try
    d = Libdl.dlopen_e(l)
    if d != C_NULL
        global found = true
        write_depsfile(l)
        break
    end
end

function _print_GUROBI_HOME_help()
    println("""
    You should set the `GUROBI_HOME` environment variable to point to the
    install location then try again. For example (updating the path to the
    correct location if needed):
    ```
    # On Windows, this might be
    ENV["GUROBI_HOME"] = "C:\\Program Files\\gurobi902\\win64\\"
    import Pkg
    Pkg.add("Gurobi")
    Pkg.build("Gurobi")

    # On OSX, this might be
    ENV["GUROBI_HOME"] = "/Library/gurobi902/mac64/"
    import Pkg
    Pkg.add("Gurobi")
    Pkg.build("Gurobi")

    # On Unix, this might be
    ENV["GUROBI_HOME"] = "/opt/gurobi902/linux64/"
    import Pkg
    Pkg.add("Gurobi")
    Pkg.build("Gurobi")
    ```
    """)
end

function diagnose_gurobi_install()
    println("""
    Unable to locate Gurobi installation. Running some common diagnostics.

    Gurobi.jl only supports the following versions:
    """)
    println.(" - ", ALIASES)
    println("""

    Did you download and install one of these versions from gurobi.com?

    """)
    if haskey(ENV, "GUROBI_HOME")
        dir = joinpath(ENV["GUROBI_HOME"], Sys.isunix() ? "lib" : "bin")
        println("""
        Found GUROBI_HOME =  $(ENV["GUROBI_HOME"])

        Does this point to the correct install location?

        We're going to look for the Gurobi library in this directory:
            $(dir)

        That directory has the following files:
        """)
        try
            for file in readdir(dir)
                println(" - ", joinpath(dir, file))
            end
            println("""

            We were looking for (but could not find) a file named like
            `libgurobiXXX.so`, `libgurobiXXX.dylib`, or `gurobiXXX.dll`.\n\n""")

            _print_GUROBI_HOME_help()
        catch ex
            if typeof(ex) <: SystemError
                println("""
                Aha! We tried looking in `$(dir)`, but something went wrong. Are
                you sure that your GUROBI_HOME environment variable is correct?
                When combined with the appropriate suffix (e.g., `lib` or
                `bin`, it needs to point to a valid directory.\n\n""")
                _print_GUROBI_HOME_help()
            else
                rethrow(ex)
            end
        end
    else
        try
            # Try to call `gurobi_cl`. This should work if Gurobi is on the
            # system path. If it succeeds, it will print out the version.
            io = IOBuffer()
            run(pipeline(`gurobi_cl --version`; stdout = io))
            seekstart(io)
            println("""

            We couldn't find the `GUROBI_HOME` environment variable, but we
            found this version of Gurobi on your path.

            $(read(io, String))
            Is this version one of the supported versions listed above? If so,
            we found the executable, but not the libraries we need. Follow the
            advice below to set the `GUROBI_HOME` environment variable. If not,
            you should edit your `PATH` to point to the correct version, or set
            the `GUROBI_HOME` environment variable.\n\n""")
            _print_GUROBI_HOME_help()
        catch
            println("""

            We could not find a version of Gurobi in your path, and we could
            not find the environment variable `GUROBI_HOME`.\n\n""")
            _print_GUROBI_HOME_help()
        end
    end
end

if !found && !haskey(ENV, "GUROBI_JL_SKIP_LIB_CHECK")
    diagnose_gurobi_install()
    error("""
    Unable to locate Gurobi installation. If the advice above did not help,
    open an issue at https://github.com/jump-dev/Gurobi.jl and post the full
    print-out of this diagnostic attempt.
    """)
end
