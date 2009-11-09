use strict;
use warnings;
use ExtUtils::MakeMaker;
use 5.008003;

my $MM_Version = $ExtUtils::MakeMaker::VERSION;

if ( $MM_Version =~ /_/ )    # dev version
{
    $MM_Version = eval $MM_Version;
    die $@ if ($@);
}

my %required = (
    'Search::Tools'      => '0.30',
    'File::Basename'     => 0,
    'MIME::Types'        => 0,
    'Path::Class'        => 0,
    'SWISH::Filter'      => '0.09',
    'Rose::ObjectX::CAF' => 0,        # Search::Tools also requires this
    'File::Temp'         => 0,
    'Data::Dump'         => 0,        # Search::Tools also requires this
    'Config::General'    => '2.31',
    'Scalar::Util'       => 0,
    'Test::More'         => 0,
    'File::Slurp'        => 0,        # Search::Tools also requires this
    'XML::Simple'        => 0,
);

my %recommended = (

    'File::Find'     => 0,    # should be part of base install just like Carp
    'WWW::Mechanize' => 0,
    'URI'            => 0,
    'SWISH::API::Object' => 0.12,    # native searcher requires
);

my %optional = (
    'YAML::Syck' => '0.72',
    'JSON::XS'   => 2.2222,
    'Mail::Box'  => 0,
    'DBI'        => 0,
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
    NAME          => 'SWISH::Prog',
    VERSION_FROM  => 'lib/SWISH/Prog.pm',
    AUTHOR        => q{Peter Karman <karman@cpan.org>},
    PREREQ_PM     => { %required, %extra, },
    ABSTRACT_FROM => 'lib/SWISH/Prog.pm',
    PL_FILES      => {},
    dist          => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean         => {
        FILES =>
            't/dbi_index t/swishobjects t/testindex t/object.index t/xapian_index'
    },
    ( $MM_Version >= 6.48 ? ( MIN_PERL_VERSION => '5.8.3' ) : () ),
    ( $MM_Version >= 6.31 ? ( LICENSE          => 'perl' )  : () ),
    (   $MM_Version <= 6.44 ? ()
        :

            (
            META_MERGE => {
                resources => {
                    license  => 'http://dev.perl.org/licenses/',
                    homepage => 'http://dev.swish-e.org/wiki/perl',
                    bugtracker =>
                        'http://rt.cpan.org/NoAuth/Bugs.html?Dist=SWISH-Prog',
                    repository => 'http://svn.swish-e.org/perl/SWISH-Prog/',
                },
            }
            )
    ),

);
