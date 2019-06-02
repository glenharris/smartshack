import * as FsExtra from 'fs-extra';
import * as Minimist from 'minimist';
import * as Os from 'os';
import * as Path from 'path';
import * as Process from 'process';
import * as Tar from 'tar';
import * as Uuid from 'uuid';
import * as Winston from 'winston';

const winston = Winston.createLogger({
    format: Winston.format.combine(
        Winston.format.splat(),
        Winston.format.simple(),
    ),
    transports: [new Winston.transports.Console()]
});
(<any>winston).level = 'debug';

async function extract(sourceFile: string, destinationFolder: string): Promise<string> {
    await Tar.extract({
        file: sourceFile,
        cwd: destinationFolder,
    });
    return destinationFolder;
}

async function copyUserScripts(sourceFolder: string, destinationFolder: string): Promise<string[]> {
    const returnValue = [];
    const sourceUserFolder = Path.resolve(sourceFolder, 'user');
    const destinationUserFolder = Path.resolve(destinationFolder, 'user');
    await FsExtra.ensureDir(destinationUserFolder);
    for (let file of await FsExtra.readdir(sourceUserFolder)) {
        if (file.endsWith('.luas')) {
            const baseName = Path.basename(file, '.luas');
            const destinationFile = Path.resolve(destinationUserFolder, `${baseName}.lua`);
            const sourceFile = Path.resolve(sourceUserFolder, file);
            winston.info('Copying %s from %s', baseName, sourceFile);
            await FsExtra.copy(sourceFile, destinationFile);
            returnValue.push(`user/${baseName}`);
        }
    }
    return returnValue;
}

async function saveOptionalScript(scriptData: any[], name: string, destinationFolder: string): Promise<string> {
    let data = scriptData.find((localData) => localData.type === name && localData.name === name);
    if (data) {
        let luaText = data.script;
        if (luaText) {
            await FsExtra.writeFile(Path.resolve(destinationFolder, `${name}.lua`), luaText);
            return name;
        }
    }
}
async function copySpecialScripts(sourceFolder: string, destinationFolder: string): Promise<string[]> {
    const returnValue = [];
    const sourceFile = Path.resolve(sourceFolder, 'scripts.json');
    const destinationFile = Path.resolve(destinationFolder, 'scripts.json');
    await FsExtra.copy(sourceFile, destinationFile);
    const destinationSystemFolder = Path.resolve(destinationFolder, 'system');
    await FsExtra.ensureDir(destinationSystemFolder);
    const scriptData = await FsExtra.readJson(sourceFile);
    for (let script of ['userlib', 'initscript']) {
        let fullName = await saveOptionalScript(scriptData, script, destinationSystemFolder);
        if (fullName) {
            winston.info('Found %s', script);
            returnValue.push(`system/${script}`);
        }
    }
    for (let scriptType of ['resident', 'event']) {
        const destinationTypeFolder = Path.resolve(destinationFolder, scriptType);
        await FsExtra.ensureDir(destinationTypeFolder);
        for (let data of scriptData) {
            if (data.type === scriptType) {
                let name = data.name;
                name = name.replace(/([^a-z0-9 ]+)/gi, '-');
                const scriptName = data.id;
                const sourceFile = Path.resolve(sourceFolder, `${scriptName}.lua`);
                const destinationFile = Path.resolve(destinationTypeFolder, `${name}.lua`);
                winston.info('Extracting %s', name);
                await FsExtra.copy(sourceFile, destinationFile);
            }
        }
    }
    return returnValue;
}


async function updateFromZip(sourceFile: string) {
    const destinationFolder = Path.resolve('temp', Uuid.v4());
    await FsExtra.mkdirp(destinationFolder);
    await extract(sourceFile, destinationFolder);
    winston.info('Extracted raw scripts to %s', destinationFolder);
    const workingFolder = Path.resolve('current');
    if (await FsExtra.pathExists(workingFolder)) {
        await FsExtra.remove(workingFolder);
    }
    await FsExtra.mkdirp(workingFolder);
    await copyUserScripts(destinationFolder, workingFolder);
    await copySpecialScripts(destinationFolder, workingFolder);
}

async function extractScripts(argv) {
    let sourceFile = '';
    if (argv._.length) {
        sourceFile = argv._[0];
    }
    if (!sourceFile) {
        const downloadFolder = Path.resolve(Os.homedir(), 'Downloads');
        let files = await FsExtra.readdir(downloadFolder);
        files = files.filter((file) => file.startsWith('Scripting-5500SHAC'));
        files.sort();
        files.reverse();
        if (files.length) {
            const recentFile = files[0];
            sourceFile = Path.resolve(downloadFolder, recentFile);
        }
    }
    if (!sourceFile) {
        sourceFile = 'downloads/current.tar.gz';
    }
    sourceFile = Path.resolve(sourceFile);
    if (!await FsExtra.pathExists(sourceFile)) {
        throw new Error(`Unable to find file ${sourceFile}`);
    }
    winston.info('About to process %s', sourceFile);
    await updateFromZip(sourceFile);
    winston.info('\ncp -r current/user/* src/');
    winston.info('\ndiff -r current/user src');
    winston.info('\ndiff -r -q current/user src');
}

let argv = Minimist(Process.argv.slice(2));
extractScripts(argv);
