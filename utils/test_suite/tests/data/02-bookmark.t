#! /usr/bin/perl -w

use Test::More qw( no_plan );
use Test::Mocking;

use strict;
use warnings;

BEGIN {
  use_ok( 'EnsEMBL::Web::Data::Bookmark' );
}

mock_registry;

my $bookmark = EnsEMBL::Web::Data::Bookmark->new();

isa_ok( $bookmark, 'EnsEMBL::Web::Data::Bookmark' );
ok( $bookmark->get_record_type eq 'bookmark', 'bookmark type is bookmark');

my $url = "http://www.ensembl.org";
my $title = "Ensembl";
my $id = 66;

ok ($bookmark->has_id == 0, 'Bookmark is without ID');

$bookmark->id($id);
$bookmark->url($url);
$bookmark->title($title);

ok($bookmark->has_id == 1, 'Bookmark has ID');
ok($bookmark->id() == $id, 'ID is ' . $id);
ok($bookmark->url() eq $url, 'URL is ' . $url);
ok($bookmark->title() eq $title, 'title is ' . $title);

## Relational tests
ok ($bookmark->get_belongs_to->[0] eq 'EnsEMBL::Web::Data::User', 'Bookmark belongs to User');

## DB tests
ok($bookmark->save == 1, 'Bookmark will save');
