package EnsEMBL::Web::Object::ArchiveStableId;


=head1 NAME


=head1 DESCRIPTION

This object stores ensembl snp objects and provides a thin wrapper around the
  ensembl-core-api. It also can create a snp render object

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 CONTACT

Fiona Cunningham - webmaster@sanger.ac.uk

=cut

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Object;
our @ISA = qw(EnsEMBL::Web::Object);


sub stable_id {
  my $self = shift;
  return $self->Obj->stable_id;
}

sub version {
  my $self = shift;
  return $self->Obj->version;
}

sub type {
  my $self = shift;
  return $self->Obj->type;
}

sub get_current_object {
  my ($self, $type, $id, $version) = @_;
  $type = ucfirst(lc($type));
  $type = 'Translation' if $type eq 'Peptide';
  $id ||= $self->stable_id;
  my $call = "get_$type"."Adaptor";
  my $adaptor = $self->database('core')->$call;
  my $object = $adaptor->fetch_by_stable_id($id);

  return undef unless $object;
  $version ||= $self->version;

  return undef unless $object->version eq $version;
  return $object || undef;
}

sub transcript {
  my $self = shift;
  return $self->Obj->get_all_transcript_archive_ids;
}

sub release {
  my $self = shift;
  return $self->Obj->release;
}

sub assembly {
  my $self = shift;
  return $self->Obj->assembly;
}

sub db_name {
  my $self = shift;
  return $self->Obj->db_name;
}

sub peptide {
  my $self = shift;
  return $self->Obj->get_all_translation_archive_ids;
}

sub _adaptor {
  my $self = shift;
  return $self->database('core')->get_ArchiveStableIdAdaptor;
}

sub history {
  my $self = shift;
  my $adaptor = $self->_adaptor;
  return unless $adaptor;
  my $history = $adaptor->fetch_archive_id_history($self->Obj);
  return $history;
}

sub dbnames {
  my $self = shift;
  my $adaptor = $self->_adaptor;
  return unless $adaptor;
  return $adaptor->list_dbnames;
}

1;
