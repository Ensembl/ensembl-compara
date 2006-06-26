package EnsEMBL::Web::Configuration::ArchiveStableId;

use strict;
use EnsEMBL::Web::Configuration;

our @ISA = qw( EnsEMBL::Web::Configuration );

sub idhistoryview {
  my $self   = shift;
  my $obj    = $self->{'object'}; 

  # Description : prints a two col table with info
  if (my $info_panel = $self->new_panel('Information',
    'code'    => "info$self->{flag}",
    'caption' => 'ID History Report',
				       )) {

    $info_panel->add_components(qw(
    name       EnsEMBL::Web::Component::ArchiveStableId::name
    db_name    EnsEMBL::Web::Component::ArchiveStableId::status
    remapped   EnsEMBL::Web::Component::ArchiveStableId::remapped
    archive    EnsEMBL::Web::Component::ArchiveStableId::archive
    associated_ids EnsEMBL::Web::Component::ArchiveStableId::associated_ids
     ));
    $self->{page}->content->add_panel( $info_panel );
  }

  if (my $panel1 = $self->new_panel('SpreadSheet',
    'code'    => "info$self->{flag}",
    'caption' => 'ID Mapping History',
    'null_data' => "<p>".$obj->stable_id. " has no successors or predecessors.</p>",
				   )) {
    $panel1->add_components(qw(
      history    EnsEMBL::Web::Component::ArchiveStableId::history
			     ));
   $self->{page}->content->add_panel( $panel1 );
 }

}

sub context_menu {
  my $self = shift;
  my $obj  = $self->{'object'};
  my $species = $obj->species;
  my @genes ;#= @{ $obj->get_genes };
  foreach my $gene (@genes) {
    $self->add_entry(
        "snp$self->{flag}", 
        'code' => 'gene_snp_info',
        'text' => "Gene SNP info",
	"title" => "GeneSNPView - SNPs and their coding consequences",
	'href' => "/$species/genesnpview?gene=".$gene->stable_id
    );
  }

}


1;
