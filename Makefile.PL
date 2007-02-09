use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'SWISH::Prog',
    VERSION_FROM => 'lib/SWISH/Prog.pm',    # finds $VERSION
    PREREQ_PM    => {

        'Search::Tools'         => '0.01',
        'File::Basename'        => '0.01',
        'IO::All'               => '0.01',
        'MIME::Types'           => '0.01',
        'File::Copy'            => '0.01',
        'SWISH::Filter'         => '0.07',
        'Class::Accessor::Fast' => '0.01',
        'File::Temp'            => '0.01',
        'Data::Dump'            => '0.01',
        'Config::General'       => '2.31',
        'YAML::Syck'            => '0.72',

    },    # e.g., Module::Name => 1.1
    (
     $] >= 5.006
     ?    ## Add these new keywords supported since 5.005
       (
         ABSTRACT_FROM => 'lib/SWISH/Prog.pm',   # retrieve abstract from module
         AUTHOR => 'Peter Karman <karman@cpan.org>'
       )
     : ()
    ),
    clean => {
        FILES =>
          'swishobjects swishobjects.prop testindex testindex.prop index.swish-e index.swish-e.prop'
    },

);
