use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'SWISH::Prog',
    VERSION_FROM => 'lib/SWISH/Prog.pm',    # finds $VERSION
    PREREQ_PM    => {

        'Search::Tools'         => '0.01',
        'File::Slurp'           => '0.01',
        'File::Basename'        => '0.01',
        'File::stat'            => '0.01',
        'File::Type'            => '0.01',
        'SWISH::Filter'         => '0.03',
        'Class::Accessor::Fast' => '0.01',
        'File::Find'            => '0.01',
        'File::Temp'            => '0.01',
        'Data::Dumper'          => '0.01',

    },    # e.g., Module::Name => 1.1
    (
     $] >= 5.006
     ?    ## Add these new keywords supported since 5.005
       (
         ABSTRACT_FROM => 'lib/SWISH/Prog.pm',   # retrieve abstract from module
         AUTHOR => 'Peter Karman <perl@peknet.com>'
       )
     : ()
    ),
);
