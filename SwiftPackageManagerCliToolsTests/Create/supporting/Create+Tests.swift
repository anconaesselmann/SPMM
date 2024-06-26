//  Created by Axel Ancona Esselmann on 6/7/24.
//

import Foundation

extension Create {
    func setup_testing() -> Self {
        var copy = self
        copy.directory = nil
        copy.group = nil
        copy.testTargets = false
        copy.target = []
        copy.verbose = false
        copy.spmfile = nil
        copy.cloneToClspmDir = false
        copy.packageCacheDir = nil
        return copy
    }
}
