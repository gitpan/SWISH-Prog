use ExtUtils::MakeMaker;

my %required = (
    'Search::Tools'         => '0.16',    # important version
    'File::Basename'        => 0,
    'MIME::Types'           => 0,
    'Path::Class'           => 0,
    'SWISH::Filter'         => '0.09',
    'Class::Accessor::Fast' => 0,
    'File::Temp'            => 0,
    'Data::Dump'            => 0,
    'Config::General'       => '2.31',
    'Scalar::Util'          => 0,
    'Test::More'            => 0,
    'File::Slurp'           => 0,         # Search::Tools also requires this
    'Search::QueryParser::SQL' => 0,
    'XML::Simple'           => 0,
    'SWISH::API::Object'    => 0.12,      # native searcher requires
);

my %recommended = (

    'File::Find'     => 0,    # should be part of base install just like Carp
    'WWW::Mechanize' => 0,
    'URI'            => 0,

);

my %optional = (
    'YAML::Syck'     => '0.72',
    'JSON::XS'       => 2.2222,
    'Mail::Box'      => 0,
    'DBI'            => 0,
);

my %extra;

# ask which of the optional modules should be installed
for my $class ( sort keys %recommended ) {
    my $vers = $recommended{$class};
    if ($vers) {
        eval "use $class $vers";
    }
    else {
        eval "use $class";
    }
    if ($@) {
        my $reply
            = prompt( "$class is recommended. Add it to CPAN install list?",
            'yes' );
        if ( $reply =~ m/^y/i ) {
            $extra{$class} = $vers;
        }
    }
}
for my $class ( sort keys %optional ) {
    my $vers = $optional{$class};
    if ($vers) {
        eval "use $class $vers";
    }
    else {
        eval "use $class";
    }
    if ($@) {
        my $reply
            = prompt( "$class is optional. Add it to CPAN install list?",
            'no' );
        if ( $reply =~ m/^y/i ) {
            $extra{$class} = $vers;
        }
    }
}

WriteMakefile(
    NAME         => 'SWISH::Prog',
    VERSION_FROM => 'lib/SWISH/Prog.pm',
    PREREQ_PM    => { %required, %extra, },
    (   $] >= 5.006
        ?    ## Add these new keywords supported since 5.005
            (
            ABSTRACT_FROM =>
                'lib/SWISH/Prog.pm',    # retrieve abstract from module
            AUTHOR => 'Peter Karman <karman@cpan.org>'
            )
        : ()
    ),
    clean => {
        FILES =>
            't/dbi_index t/swishobjects t/testindex t/object.index t/xapian_index'
    },

);
