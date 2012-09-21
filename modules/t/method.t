#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Bio::EnsEMBL::Utils::Exception qw (warning);
use Bio::EnsEMBL::Compara::Method;
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );

my $compara_dba = $multi->get_DBAdaptor( "compara" );
  
# 
# Test new method
# 

subtest "Test Bio::EnsEMBL::Compara::Method::new(ALL) method", sub {

    my $method_id = 1;
    my $type = "LASTZ_NET";
    my $class = "GenomicAlignBlock.pairwise_alignment";
    my $string = "Bio::EnsEMBL::Compara::Method: dbID=$method_id, type='$type', class='$class'";

    my $method = new Bio::EnsEMBL::Compara::Method(
                                                   -dbID => $method_id,
                                                   -type => $type,
                                                   -class => $class);
    isa_ok($method, "Bio::EnsEMBL::Compara::Method");
    is($method->dbID, $method_id);
    is($method->type, $type);
    is($method->class, $class);
    is ($method->toString, $string);

    done_testing();
};

done_testing();

