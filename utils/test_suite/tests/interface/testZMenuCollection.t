#! /usr/bin/perl -w

use Test::More qw( no_plan );
use strict;

BEGIN {
  use_ok ( 'EnsEMBL::Web::Interface::ZMenuCollection' );
}

my $collection = EnsEMBL::Web::Interface::ZMenuCollection->new;
isa_ok($collection, "EnsEMBL::Web::Interface::ZMenuCollection");
$collection->add_zmenu( ( 
                        title => 'CH001_HUMAN', 
                        type => 'GENE',
                        ident => 'ENSG00000164823',
                        content => [ 
                                     { type => 'text',
                                       value => 'BP: 90983269-91009271' },
                                     { type => 'text',
                                       value => 'Length: 26003' }
                                   ]
                      ) );

my $zmenu = $collection->zmenu_by_title('CH001_HUMAN');
ok($collection->size == 1);
ok($zmenu->title eq "CH001_HUMAN");
