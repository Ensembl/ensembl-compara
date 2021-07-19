=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Command::UserData::ModifyData;

### Simple redirect that calls a method on the UserData object and redirects back
### to the ManageData page

use strict;

use Digest::MD5 qw(md5_hex);

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self    = shift;
  my $hub     = $self->hub;
  my $func    = 'md_'.$hub->function;
  my $object  = $self->object;
  my $rtn     = $object->$func();

  if ($rtn) {
    print 'reload';
  }
  else {
    $self->ajax_redirect($hub->url({
      action   => 'ManageData',
      function => undef,
      __clear  => 1,
      reload   => 1,
    }));
  }
}

1;
