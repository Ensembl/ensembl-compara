#! /usr/bin/perl -w

use Test::More qw( no_plan );
use strict;

BEGIN {
  use_ok ( 'EnsEMBL::Web::Interface::ZMenu' );
}

my $title = "CH001_HUMAN";
my $type = "gene";
my $ident = "ENSG00000164823";

my $zmenu = EnsEMBL::Web::Interface::ZMenu->new( ( 
                    title => $title,
                     type => $type,
                    ident => $ident,
              placeholder => 'yes'
                 ) );

isa_ok($zmenu, "EnsEMBL::Web::Interface::ZMenu");

ok($zmenu->title eq $title);
ok($zmenu->type eq $type);
ok($zmenu->ident eq $ident);

isa_ok($zmenu->add_list->[0], 'EnsEMBL::Web::Interface::ZMenuItem::Placeholder');
ok($zmenu->add_list->[0]->type eq 'placeholder'); 
ok($zmenu->add_list->[0]->name eq 'placeholder'); 

$zmenu->add_text('new text', 'Some text');
isa_ok($zmenu->add_list->[1], 'EnsEMBL::Web::Interface::ZMenuItem::Text');
ok($zmenu->add_list->[1]->type eq 'text'); 
ok($zmenu->add_list->[1]->name eq 'new text'); 
ok($zmenu->add_list->[1]->text eq 'Some text'); 

$zmenu->remove_placeholder();

ok($zmenu->remove_list->[0] eq 'placeholder');
