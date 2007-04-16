package Bio::EnsEMBL::GlyphSetManager::sub_repeat;

use strict;
use Bio::EnsEMBL::GlyphSetManager;
use Bio::EnsEMBL::GlyphSet::sub_repeat;
use vars qw(@ISA);
@ISA = qw(Bio::EnsEMBL::GlyphSetManager);

##
## 2001/07/03	js5		Added external DAS source code
## 2001/07/04	js5		Added sub add_glyphset to remove duplication in code in init!
##

sub init {
  my ($self) = @_;
  $self->label("Repeats");
  my $Config = $self->{'config'};
  my $sub_repeats = $Config->{species_defs}->REPEAT_TYPES;
  return unless ref($sub_repeats) eq 'HASH';
  foreach my $name ( sort keys %$sub_repeats) {
    ( my $N = $name ) =~s/\W+/_/g;  
    next unless( $Config->get("managed_repeat_$N",'on') eq 'on' );
    $self->add_glyphset( $name );
  }
}

sub add_glyphset {
   my ($self,$name ) = @_;	
		
   my $sub_repeat_glyphset;

   eval { $sub_repeat_glyphset = new Bio::EnsEMBL::GlyphSet::sub_repeat( $self->{'container'}, $self->{'config'}, $self->{'highlights'}, $self->{'strand'}, { 'name' => $name } ); };
							   
   if($@) {
      warn "REPEAT GLYPHSET $name failed\n\t'$@'";
   } else {
      push @{$self->{'glyphsets'}}, $sub_repeat_glyphset;
   }
}

1;
