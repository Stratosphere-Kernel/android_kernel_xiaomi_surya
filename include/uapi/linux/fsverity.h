/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */
/*
 * fs-verity user API
 *
 * These ioctls can be used on filesystems that support fs-verity.  See the
 * "User API" section of Documentation/filesystems/fsverity.rst.
 *
 * Copyright 2019 Google LLC
 */
#ifndef _UAPI_LINUX_FSVERITY_H
#define _UAPI_LINUX_FSVERITY_H

#include <linux/ioctl.h>
#include <linux/types.h>

#define FS_VERITY_HASH_ALG_SHA256	1
#define FS_VERITY_HASH_ALG_SHA512	2

struct fsverity_enable_arg {
	__u32 version;
	__u32 hash_algorithm;
	__u32 block_size;
	__u32 salt_size;
	__u64 salt_ptr;
	__u32 sig_size;
	__u32 __reserved1;
	__u64 sig_ptr;
	__u64 __reserved2[11];
};

struct fsverity_digest {
	__u16 digest_algorithm;
	__u16 digest_size; /* input/output */
	__u8 digest[];
};

struct fsverity_read_metadata_arg {
	__u64 metadata_type;
	__u64 offset;
	__u64 length;
	__u64 buf_ptr;
	__u64 __reserved;
};

#define FS_IOC_ENABLE_VERITY	_IOW('f', 133, struct fsverity_enable_arg)
#define FS_IOC_MEASURE_VERITY	_IOWR('f', 134, struct fsverity_digest)
#define FS_IOC_READ_VERITY_METADATA \
	_IOWR('f', 135, struct fsverity_read_metadata_arg)

#endif /* _UAPI_LINUX_FSVERITY_H */
