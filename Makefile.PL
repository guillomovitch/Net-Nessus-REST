use ExtUtils::MakeMaker;

WriteMakefile(
    NAME           => 'Net::Nessus::REST',
    VERSION_FROM   => 'lib/Net/Nessus/REST.pm',
    ABSTRACT_FROM  => 'lib/Net/Nessus/REST.pm',
    LICENSE        => 'GPL_3',
    PREREQ_PM => {
        'JSON'           => 0,
        'LWP::UserAgent' => 0,
    },
    TEST_REQUIRES  => {
        'Test::More' => 0,
    }
);
