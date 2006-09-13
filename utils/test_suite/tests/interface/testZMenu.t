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
                   ident => $ident
                 ) );

isa_ok($zmenu, "EnsEMBL::Web::Interface::ZMenu");

ok($zmenu->title eq $title);
ok($zmenu->type eq $type);
ok($zmenu->ident eq $ident);

my @content = ( 
                { 
                  type => 'text',
                  value => 'BP: 90983269-91009271'
                },
                { 
                  type => 'text',
                  value => 'Length: 26003'
                },
                { 
                  type => 'text',
                  value => 'Protein coding'
                },
                {
                  name => 'geneview link',
                  type => 'link',
                  value => 'http://www.ensembl.org/Homo_sapiens/geneview?gene=ENSG00000164823;db=core',
                  text => '<a href="{{value}}">View</a>'
                }
              );

$zmenu->content(\@content);
my @zmenu_content = @{ $zmenu->content };
ok($zmenu_content[0]->{type} eq 'text'); 
ok($zmenu_content[0]->{value} eq 'BP: 90983269-91009271'); 

my %named_content = %{ $zmenu->content_with_name('geneview link') }; 
ok($named_content{type} eq 'link');
ok($named_content{value} eq 'http://www.ensembl.org/Homo_sapiens/geneview?gene=ENSG00000164823;db=core');

ok ($zmenu->size == 4);
$zmenu->add_content({ name => 'gene id', 
                      type => 'text',
                      value => 'ENS12398129378' });
ok ($zmenu->size == 5);

$zmenu->add_text({ name => 'another gene id', value => 'ENS12937129378' });
ok ($zmenu->size == 6);

@zmenu_content = @{ $zmenu->content };
%named_content = %{ $zmenu_content[5] };
ok ($named_content{type} eq 'text');
ok ($named_content{name} eq 'another gene id');
ok ($zmenu->overview eq $zmenu->title);
