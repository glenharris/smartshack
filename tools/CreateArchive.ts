import * as FsExtra from 'fs-extra';
import * as Minimist from 'minimist';
import * as moment from 'moment';
import * as Path from 'path';
import * as Process from 'process';
import * as Tar from 'tar';
import * as Winston from 'winston';

const winston = Winston.createLogger({
    format: Winston.format.combine(
        Winston.format.splat(),
        Winston.format.simple(),
    ),
    transports: [new Winston.transports.Console()]
});
(<any>winston).level = 'debug';
const logger = winston;
async function compress(destinationFile: string, sourceFolder: string, files: string[]): Promise<string> {
    if (!files) {
        files = await FsExtra.readdir(sourceFolder);
    }
    logger.info('About to compress to %s from %s (%s)', destinationFile, sourceFolder, files);
    await Tar.create({
        gzip: true,
        file: destinationFile,
        cwd: sourceFolder,
    }, files);
    return destinationFile;
}

async function copyScripts(sourceFolder: string, destinationFolder: string) {
    for (let file of await FsExtra.readdir(sourceFolder)) {
        if (file.endsWith('.lua')) {
            const baseName = Path.basename(file, '.lua');
            const destinationFile = Path.resolve(destinationFolder, `${baseName}.luas`);
            const sourceFile = Path.resolve(sourceFolder, file);
            winston.info('Copying %s from %s', baseName, sourceFile);
            await FsExtra.copy(sourceFile, destinationFile);
        }
    }
}
async function createArchive(argv) {
    const archiveFolder = Path.resolve('temp-archive');
    await FsExtra.remove(archiveFolder);
    await FsExtra.mkdirp(archiveFolder);
    const userFolder = Path.resolve(archiveFolder, 'user');
    await FsExtra.mkdirp(userFolder);
    const sourceFolder = Path.resolve('src');
    // await FsExtra.copy(sourceFolder, userFolder);
    await copyScripts(sourceFolder, userFolder);
    const date = moment().format('YYYY.MM.DD-HH.mm');
    // const archiveFile = Path.resolve(`Libraries-5500SHAC-${date}.tar.gz`);
    // const archiveFile = Path.resolve(`Current.tar.gz`);
    const archiveFile = Path.resolve(`SmartShack-${date}.tar.gz`);
    await FsExtra.copy(Path.resolve('archive'), archiveFolder);
    await compress(archiveFile, archiveFolder, ['./scripts.json', './user']);
    await FsExtra.copy(archiveFile, Path.resolve('Current.tar.gz'));
}

let argv = Minimist(Process.argv.slice(2));
createArchive(argv);
