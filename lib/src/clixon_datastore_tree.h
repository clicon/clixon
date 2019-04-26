/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2019 Olof Hagsand and Benny Holmgren

  This file is part of CLIXON.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

  Alternatively, the contents of this file may be used under the terms of
  the GNU General Public License Version 3 or later (the "GPL"),
  in which case the provisions of the GPL are applicable instead
  of those above. If you wish to allow use of your version of this file only
  under the terms of the GPL, and not to allow others to
  use your version of this file under the terms of Apache License version 2, 
  indicate your decision by deleting the provisions above and replace them with
  the  notice and other provisions required by the GPL. If you do not delete
  the provisions above, a recipient may use your version of this file under
  the terms of any one of the Apache License version 2 or the GPL.

  ***** END LICENSE BLOCK *****

 *
 * Datastore block tree file
 */

#ifndef _CLIXON_DATASTORE_TREE_H_
#define _CLIXON_DATASTORE_TREE_H_

/*
 * Constants and macros
 */
/* Max of https://github.com/YangModels/yang
 * name:      receive-recovery-scccp-avp-bad-value-challenge-response
 * namespace: urn:ieee:std:802.3:yang:ieee802-ethernet-interface-half-duplex
 */
#define DF_BLOCK 32

/*
 * Types
 */
/* On file                      value (dep of type)
 * off: Offset in bytes to where value starts (name ends +1)
 * len: Total length in bytes (network byte order)
 * childi: Block index to child (network byte order)
 * ELMNT:                       
 * +-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
 * | 1   | 128 | de  | ad  | len                   | name ...  |  0  |
 * +-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
 * +-----+-----+-----+-----+-----+-----+-----+------+--
 * | child0 (index in file)|  child1 (index in file)|
 * +-----+-----+-----+-----+-----+-----+-----+-----+--
 * ATTR:
 * +-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
 * | 1   | 129 | de  | ad  | len                   | name  ... |  0  |
 * +-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
 * +-----+-----+-----+
 * | value ... | 0   |
 * +-----+-----+-----+
 * BODY: (off = 8)
 * +-----+-----+-----+-----+-----+-----+-----+-----+-----+
 * | 1   | 130 | de  | ad  |   len                 | 0   |
 * +-----+-----+-----+-----+-----+-----+-----+-----+-----+
 * +-----+-----+-----+
 * | value ... | 0   |
 * +-----+-----+-----+
 * FREE
 * +------+
 * | 0    |
 * +------+
*/

/*
 * Prototypes
 */
int datastore_tree_write(clicon_handle h, char *filename, cxobj *xt);
int datastore_tree_read(clicon_handle h, char *filename, cxobj **xt);

#endif  /* _CLIXON_DATASTORE_TREE_H_ */
