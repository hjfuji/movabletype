#!/usr/bin/perl

use strict;
use warnings;

BEGIN {
    $ENV{MT_CONFIG} = 'mysql-test.cfg';
}

BEGIN {
    use Test::More;
    eval { require Test::MockModule }
        or plan skip_all => 'Test::MockModule is not installed';
}

use lib qw(lib extlib t/lib);

use Test::More;
eval(
    $ENV{SKIP_REINITIALIZE_DATABASE}
    ? "use MT::Test;"
    : "use MT::Test qw(:db :data);"
);

use MT::App::DataAPI;
use MT::DataAPI::Resource;

my $app = MT::App::DataAPI->new;
MT->set_instance($app);
my $user_class = $app->model('user');
my $author     = MT->model('author')->load(1);

my $mock_author = Test::MockModule->new('MT::Author');
$mock_author->mock( 'is_superuser', sub {0} );
my $mock_app_api = Test::MockModule->new('MT::App::DataAPI');
$mock_app_api->mock( 'user', $author );

subtest 'from_object with $fields_specified' => sub {
    my @suite = (
        {   from => {
                id               => 1,
                nickname         => 'Test',
                userpic_asset_id => 1,
            },
            to => {
                id          => 1,
                name        => undef,
                displayName => 'Test',
                userpicUrl =>
                    'http://narnia.na/nana/assets_c/userpics/userpic-1-100x100.png',
                language  => 'en-us',
                email     => undef,
                url       => undef,
                updatable => 1,
            },
            fields => undef,
        },
        {   from => {
                id               => 1,
                nickname         => 'Test',
                userpic_asset_id => 1,
            },
            to     => { id => 1, },
            fields => [qw(id)],
        },
        {   from => {
                id               => 1,
                nickname         => 'Test',
                userpic_asset_id => 1,
            },
            to => {
                id          => 1,
                displayName => 'Test',
            },
            fields => [qw(id displayName)],
        },
    );

    for my $d (@suite) {
        note( $d->{note} ) if $d->{note};

        my $user = $user_class->new;
        $user->set_values( $d->{from} );
        my $hash = MT::DataAPI::Resource->from_object( $user,
            ( defined( $d->{fields} ) ? $d->{fields} : () ) );
        is_deeply( $hash, $d->{to}, 'converted data' );
    }

    {
        my @users
            = map { my $u = $user_class->new; $u->set_values( $_->{from} ); $u }
            @suite;
        my $hashs = MT::DataAPI::Resource->from_object( \@users );
        my $expected
            = [ map { MT::DataAPI::Resource->from_object($_) } @users ];

        is_deeply( $hashs, $expected, 'convert data in bulk' );
    }
};

subtest 'to_object with column not allowed to overwrite' => sub {
    my @suite = (
        {   original => { id => 1, },
            from     => { id => 2, },
            to       => { id => 1, }
        },
    );

    for my $d (@suite) {
        note( $d->{note} ) if $d->{note};

        my ( $original, $expected_values );
        if ( $d->{original} ) {
            $original = $user_class->new;
            $original->set_values( $d->{original} );
            $expected_values = $original->column_values;
        }
        else {
            $expected_values = $user_class->new->column_values;
        }

        my $obj
            = MT::DataAPI::Resource->to_object( 'user', $d->{from},
            $original );
        my $values = $obj->column_values;
        foreach my $k ( keys %{ $d->{to} } ) {
            $expected_values->{$k} = $d->{to}{$k};
        }
        is_deeply( $values, $expected_values, 'converted data' );
    }
};

done_testing();
