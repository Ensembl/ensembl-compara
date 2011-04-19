#!/usr/bin/env perl

use strict;
use warnings;

use Pod::Usage;
use Getopt::Long;
use Scalar::Util qw(looks_like_number);
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::RunnableDB::MemberDisplayLabelUpdater;

my @OPTIONS = qw(
  registry|reg_conf=s
  compara=s
  species=s@
  replace
  die_if_no_core
  verbose
  help
  man
);

sub run {
  my $options = _parse_options();
  _load_registry($options);
  my $dba = _compara_dba($options);
  my $genome_db_ids = _genome_db_ids($options, $dba);
  my $runnable = _build_runnable($options, $dba, $genome_db_ids);
  $runnable->run_without_hive();
  return;
}

sub _parse_options {
  my $hash = {};
  GetOptions( $hash, @OPTIONS) or pod2usage(1);
  pod2usage( -exitstatus => 0, -verbose => 1 ) if $hash->{help};
	pod2usage( -exitstatus => 0, -verbose => 2 ) if $hash->{man};
  return $hash;
}

sub _load_registry {
  my ($options) = @_;
  Bio::EnsEMBL::Registry->load_all($options->{registry});
  return;
}

sub _compara_dba {
  my ($options) = @_;
  my $synonym = $options->{compara};
  my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor($synonym, 'compara');
  if(! defined $dba) {
    my $reg = $options->{registry} || q{-};
    print STDERR "Cannot find a compara DBAdaptor instance for the synonym ${synonym}. Check your registry (location ${reg}) to see if you have defined it\n";
    pod2usage( -exitstatus => 1, -verbose => 1 );
  }
  return $dba;
}

sub _genome_db_ids {
  my ($options, $dba) = @_;
  my $species = $options->{species};
  
  if(! defined $species) {
    print STDOUT 'Working with all available GenomeDBs', "\n" if $options->{verbose};
    return;
  }
  
  my @genome_dbs;
  foreach my $s (@{$species}) {
    if(looks_like_number($s)) {
      push(@genome_dbs, $s);
    }
    else {
      my $gdb = $dba->get_GenomeDBAdaptor()->fetch_by_registry_name($s);
      if(! defined $gdb) {
        print STDERR "$s does not have a valid GenomeDB\n";
        pod2usage( -exitstatus => 1, -verbose => 1 );
      }
      push(@genome_dbs, $gdb->dbID());
    }
  }
  return \@genome_dbs;
}

sub _build_runnable {
  my ($options, $dba, $genome_db_ids) = @_;
  
  my %args = (
    -DB_ADAPTOR => $dba,
    -REPLACE => $options->{replace},
    -DIE_IF_NO_CORE_ADAPTOR => $options->{die_if_no_core},
    -DEBUG => $options->{verbose}
  );
  $args{-GENOME_DB_IDS} = $genome_db_ids if defined $genome_db_ids;
  return Bio::EnsEMBL::Compara::RunnableDB::MemberDisplayLabelUpdater->new_without_hive(%args);
}

#Only execute method
run();
exit 0;

__END__
=pod

=head1 NAME

populate_member_display_label.pl

=head1 SYNOPSIS

  ./populate_member_display_label.pl --reg_conf my.reg --compara my_compara --species 'homo_sapiens' --replace
  
  ./populate_member_display_label.pl --reg_conf my.reg --compara my_compara --species 90 --species 91
  
  ./populate_member_display_label.pl --registry my.reg --compara my_compara

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

=item B<--registry | --reg_conf>

Specify a location of the registry file to load

=item B<--compara>

Compara database to use e.g. multi

=item B<--species>

Specify a registry alias to find a GenomeDB by; supports GenomeDB IDs & 
you can specify multiple options on the command line

=item B<--replace>

Replace any existing display labels

=item B<--die_if_no_core>

Cause the script to die if we encounter any GenomeDB without a Core DBAdaptor

=item B<--verbose>

Prints messages to STDOUT 

=item B<--help>

Help output

=item B<--man>

Manual page

=back

=cut