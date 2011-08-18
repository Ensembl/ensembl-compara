#!/usr/bin/env perl

use strict;
use warnings;

use Pod::Usage;
use Getopt::Long;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::RunnableDB::MemberDisplayLabelUpdater;

my @OPTIONS = qw(
  reg_conf|registry=s
  reg_alias|compara=s
  species=s@
  replace
  die_if_no_core_adaptor|die_if_no_core
  verbose
  help
  man
);

sub main {

  warn "NB: This script is being phased out. It may still work, but please see POD for Bio::EnsEMBL::Compara::RunnableDB::MemberDisplayLabelUpdater for examples of how we run it.\n";

  my $options = {};
  GetOptions( $options, @OPTIONS) or pod2usage(1);
    pod2usage( -exitstatus => 0, -verbose => 1 ) if $options->{help};
	pod2usage( -exitstatus => 0, -verbose => 2 ) if $options->{man};

  Bio::EnsEMBL::Registry->load_all($options->{reg_conf});

  my $dba = _compara_dba($options);

  my %args = (
    -DB_ADAPTOR => $dba,
    -REPLACE => $options->{replace},
    -DIE_IF_NO_CORE_ADAPTOR => $options->{die_if_no_core_adaptor},
    -SPECIES => $options->{species},
    -DEBUG => $options->{verbose}
  );
  my $runnable = Bio::EnsEMBL::Compara::RunnableDB::MemberDisplayLabelUpdater->new_without_hive(%args);
  $runnable->run_without_hive();
}

sub _compara_dba {
  my ($options) = @_;
  my $reg_alias = $options->{reg_alias};
  my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor($reg_alias, 'compara');
  if(! defined $dba) {
    my $reg = $options->{reg_conf} || q{-};
    print STDERR "Cannot find a compara DBAdaptor instance for the registry alias ${reg_alias}. Check your registry (location ${reg}) to see if you have defined it\n";
    pod2usage( -exitstatus => 1, -verbose => 1 );
  }
  return $dba;
}

main();
exit 0;

__END__
=pod

=head1 NAME

populate_member_display_label.pl

=head1 SYNOPSIS

  ./populate_member_display_label.pl --reg_conf my.reg --reg_alias my_compara --species 'homo_sapiens' --replace
  
  ./populate_member_display_label.pl --reg_conf my.reg --reg_alias my_compara --species 90 --species 91
  
  ./populate_member_display_label.pl --reg_conf my.reg --reg_alias my_compara

=head1 DESCRIPTION

This is a thin wrapper script to call out to the module 
C<Bio::EnsEMBL::Compara::RunnableDB::MemberDisplayLabelUpdater>. The aim
is to upate the field C<member.display_label> in the specified compara 
database. Pipelines sometimes will not load this data because it does not
exist when you run the pipeline (true for Ensembl Compara because some
display labels will depend on the projections from generated from Compara).

Options are available to force errors to appear as & when we miss out on a 
core adaptor as well as forcing the replacement of existing display labels.

You can specify the GenomeDBs to update or giving no values causes an update of
all GenomeDBs

=head1 OPTIONS

=over 8

=item B<--reg_conf>

Specify a location of the registry file to load

=item B<--reg_alias>

Compara database to use e.g. multi

=item B<--species>

Specify a registry alias to find a GenomeDB by; supports GenomeDB IDs & 
you can specify multiple options on the command line

=item B<--replace>

Replace any existing display labels

=item B<--die_if_no_core_adaptor>

Cause the script to die if we encounter any GenomeDB without a Core DBAdaptor

=item B<--verbose>

Prints messages to STDOUT 

=item B<--help>

Help output

=item B<--man>

Manual page

=back

=cut
